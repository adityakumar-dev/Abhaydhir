"use client";

import { useState, useEffect, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Sparkles,
  Send,
  CheckCircle2,
  AlertTriangle,
  ShieldCheck,
  MessageSquareHeart,
  Star,
  Heart,
  ThumbsUp,
  Award,
  XCircle,
  ArrowLeft,
  Loader2,
  CalendarOff,
  type LucideIcon,
} from "lucide-react";
import Link from "next/link";
import {
  getEventQuestions,
  submitEventAnswers,
  type FeedbackQuestion,
  type FeedbackAnswer,
} from "@/services/feedbackApi";
import {
  generateFingerprint,
  hasSubmittedFeedback,
  markFeedbackSubmitted,
} from "@/lib/fingerprint";
import { api } from "@/services/api";

/**
 * Module-level caches — survive React Strict Mode unmount→remount cycles.
 * useRef resets on every remount so it can't guard against double-calls in dev.
 */
const _eventCache = new Map<number, boolean>();
const _initDone = new Set<number>();

/* ───────────────────────── Rating Config ───────────────────────── */

interface RatingLevel {
  label: string;
  emoji: string;
  color: string;
  bg: string;
  border: string;
  glow: string;
  icon: LucideIcon;
  particles: string;
}

const ratingConfig: RatingLevel[] = [
  {
    label: "Terrible",
    emoji: "😞",
    color: "from-red-500 to-red-600",
    bg: "bg-red-50",
    border: "border-red-200",
    glow: "shadow-red-300/50",
    icon: XCircle,
    particles: "#ef4444",
  },
  {
    label: "Poor",
    emoji: "😕",
    color: "from-orange-500 to-orange-600",
    bg: "bg-orange-50",
    border: "border-orange-200",
    glow: "shadow-orange-300/50",
    icon: ThumbsUp,
    particles: "#f97316",
  },
  {
    label: "Okay",
    emoji: "😊",
    color: "from-yellow-500 to-yellow-600",
    bg: "bg-yellow-50",
    border: "border-yellow-200",
    glow: "shadow-yellow-300/50",
    icon: Star,
    particles: "#eab308",
  },
  {
    label: "Good",
    emoji: "😄",
    color: "from-green-500 to-emerald-600",
    bg: "bg-green-50",
    border: "border-green-200",
    glow: "shadow-green-300/50",
    icon: Heart,
    particles: "#22c55e",
  },
  {
    label: "Amazing!",
    emoji: "🤩",
    color: "from-violet-500 to-purple-600",
    bg: "bg-purple-50",
    border: "border-purple-200",
    glow: "shadow-purple-300/50",
    icon: Award,
    particles: "#8b5cf6",
  },
];

/* ──────────────────── Animated Star Rating ──────────────────────── */

function AnimatedStarRating({
  value,
  maxValue,
  onChange,
  disabled,
  compact,
}: {
  value: number;
  maxValue: number;
  onChange: (r: number) => void;
  disabled: boolean;
  compact?: boolean;
}) {
  const [hovered, setHovered] = useState(0);
  const [showParticles, setShowParticles] = useState(false);
  const [particleIdx, setParticleIdx] = useState(0);

  const handleRate = (r: number) => {
    if (disabled) return;
    onChange(r);
    setParticleIdx(r);
    setShowParticles(true);
    setTimeout(() => setShowParticles(false), 1200);
  };

  const active = hovered || value;
  const stars = Array.from({ length: maxValue }, (_, i) => i + 1);

  return (
    <div className="flex flex-col items-center gap-3">
      {/* Emoji & Label — only for 5-star scale */}
      {maxValue === 5 && (
        <AnimatePresence mode="wait">
          {active > 0 && (
            <motion.div
              key={active}
              initial={{ opacity: 0, y: 8, scale: 0.85 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: -8, scale: 0.85 }}
              transition={{ type: "spring", stiffness: 400, damping: 22 }}
              className="flex flex-col items-center"
            >
              <span className={compact ? "text-3xl" : "text-4xl"}>
                {ratingConfig[active - 1]?.emoji}
              </span>
              <span
                className={`text-xs font-bold bg-gradient-to-r ${ratingConfig[active - 1]?.color} bg-clip-text text-transparent`}
              >
                {ratingConfig[active - 1]?.label}
              </span>
            </motion.div>
          )}
        </AnimatePresence>
      )}

      {/* Stars / Icons */}
      <div className="relative flex items-center gap-2 flex-wrap justify-center">
        {/* Particles */}
        {showParticles &&
          particleIdx > 0 &&
          Array.from({ length: 8 }).map((_, i) => {
            const cfg = ratingConfig[(particleIdx - 1) % 5];
            return (
              <motion.div
                key={`p-${i}`}
                className="absolute rounded-full pointer-events-none"
                style={{
                  width: 5 + Math.random() * 5,
                  height: 5 + Math.random() * 5,
                  backgroundColor: cfg?.particles ?? "#8b5cf6",
                  left: `${((particleIdx - 1) / Math.max(maxValue - 1, 1)) * 100}%`,
                  top: "50%",
                }}
                initial={{ opacity: 0, scale: 0 }}
                animate={{
                  opacity: [0, 1, 0],
                  scale: [0, 1, 0],
                  y: [-10, -50 - Math.random() * 30],
                  x: [(Math.random() - 0.5) * 50],
                }}
                transition={{ duration: 1, delay: i * 0.04, ease: "easeOut" }}
              />
            );
          })}

        {stars.map((star) => {
          const isActive = star <= active;
          const cfgIdx =
            maxValue === 5
              ? star - 1
              : Math.floor(((star - 1) / Math.max(maxValue - 1, 1)) * 4);
          const cfg = ratingConfig[cfgIdx] ?? ratingConfig[4];
          const Icon = maxValue === 5 ? cfg.icon : Star;

          return (
            <motion.button
              key={star}
              type="button"
              disabled={disabled}
              onMouseEnter={() => !disabled && setHovered(star)}
              onMouseLeave={() => !disabled && setHovered(0)}
              onClick={() => handleRate(star)}
              className={`relative group ${disabled ? "cursor-not-allowed opacity-60" : "cursor-pointer"}`}
              whileHover={disabled ? {} : { scale: 1.2 }}
              whileTap={disabled ? {} : { scale: 0.85 }}
              transition={{ type: "spring", stiffness: 500, damping: 15 }}
            >
              {/* Glow */}
              <motion.div
                className={`absolute inset-0 rounded-full blur-md transition-opacity ${
                  isActive
                    ? `bg-gradient-to-r ${cfg.color} opacity-30`
                    : "opacity-0"
                }`}
                animate={{
                  scale: isActive ? 1.15 : 1,
                  opacity: isActive ? [0.2, 0.5, 0.2] : 0,
                }}
                transition={{
                  duration: 2,
                  repeat: Infinity,
                  ease: "easeInOut",
                }}
              />

              {/* Icon box */}
              <motion.div
                className={`relative z-10 ${
                  compact
                    ? "w-11 h-11 md:w-12 md:h-12 rounded-xl"
                    : "w-12 h-12 md:w-14 md:h-14 rounded-2xl"
                } flex items-center justify-center border-2 transition-all duration-300 ${
                  isActive
                    ? `bg-gradient-to-br ${cfg.color} border-transparent shadow-lg ${cfg.glow}`
                    : `bg-white/80 ${cfg.border}`
                }`}
                animate={
                  isActive ? { rotate: [0, -2, 2, 0] } : { rotate: 0 }
                }
                transition={{
                  duration: 3,
                  repeat: Infinity,
                  ease: "easeInOut",
                  type: "tween",
                }}
              >
                <Icon
                  className={`${
                    compact
                      ? "w-5 h-5 md:w-6 md:h-6"
                      : "w-6 h-6 md:w-7 md:h-7"
                  } transition-colors duration-300 ${
                    isActive ? "text-white" : "text-gray-400"
                  }`}
                  strokeWidth={isActive ? 2.5 : 1.5}
                />
              </motion.div>

              {/* Number label */}
              <span
                className={`absolute -bottom-4 left-1/2 -translate-x-1/2 text-[9px] font-bold transition-colors ${
                  isActive
                    ? `bg-gradient-to-r ${cfg.color} bg-clip-text text-transparent`
                    : "text-gray-400"
                }`}
              >
                {star}
              </span>
            </motion.button>
          );
        })}
      </div>
    </div>
  );
}

/* ──────────── Question Card — Rating ────────────── */

function RatingQuestionCard({
  question,
  value,
  onChange,
  disabled,
  index,
}: {
  question: FeedbackQuestion;
  value: number;
  onChange: (v: number) => void;
  disabled: boolean;
  index: number;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 15 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.06 * index, duration: 0.4, ease: "easeOut" }}
      className="rounded-2xl border border-gray-100 bg-white/50 backdrop-blur-sm p-5 md:p-6"
    >
      <div className="flex items-start gap-2 mb-4">
        <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-violet-100 text-violet-700 text-xs font-bold flex-shrink-0 mt-0.5">
          {index + 1}
        </span>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold text-gray-800 leading-relaxed whitespace-pre-line">
            {question.question_text}
          </p>
          {question.is_required && (
            <span className="text-[10px] text-red-400 font-medium">
              * Required
            </span>
          )}
        </div>
      </div>
      <AnimatedStarRating
        value={value}
        maxValue={question.max_value ?? 5}
        onChange={onChange}
        disabled={disabled}
        compact
      />
    </motion.div>
  );
}

/* ──────────── Question Card — Text ─────────────── */

function TextQuestionCard({
  question,
  value,
  onChange,
  disabled,
  index,
}: {
  question: FeedbackQuestion;
  value: string;
  onChange: (v: string) => void;
  disabled: boolean;
  index: number;
}) {
  const maxLen = 1000;

  return (
    <motion.div
      initial={{ opacity: 0, y: 15 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.06 * index, duration: 0.4, ease: "easeOut" }}
      className="rounded-2xl border border-gray-100 bg-white/50 backdrop-blur-sm p-5 md:p-6"
    >
      <div className="flex items-start gap-2 mb-3">
        <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-violet-100 text-violet-700 text-xs font-bold flex-shrink-0 mt-0.5">
          {index + 1}
        </span>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold text-gray-800 leading-relaxed whitespace-pre-line">
            {question.question_text}
          </p>
          {question.is_required ? (
            <span className="text-[10px] text-red-400 font-medium">
              * Required
            </span>
          ) : (
            <span className="text-[10px] text-gray-400 font-medium">
              Optional
            </span>
          )}
        </div>
      </div>
      <div className="relative">
        <textarea
          value={value}
          onChange={(e) => {
            if (e.target.value.length <= maxLen) onChange(e.target.value);
          }}
          disabled={disabled}
          placeholder="Type your answer here..."
          rows={3}
          className="w-full rounded-xl border-2 border-gray-200 bg-white/80 backdrop-blur-sm px-4 py-3 text-sm text-gray-800 placeholder-gray-400 transition-all duration-300 focus:border-violet-400 focus:ring-4 focus:ring-violet-100 focus:outline-none resize-none disabled:opacity-50"
        />
        <span
          className={`absolute bottom-2.5 right-3 text-[10px] font-medium transition-colors ${
            value.length > 900
              ? "text-red-400"
              : value.length > 700
                ? "text-amber-400"
                : "text-gray-300"
          }`}
        >
          {value.length}/{maxLen}
        </span>
      </div>
    </motion.div>
  );
}

/* ═══════════════════════ MAIN FEEDBACK PAGE ══════════════════════ */

export default function FeedbackPage({
  params,
}: {
  params: { event_id: string };
}) {
  const EVENT_ID = useMemo(() => Number(params.event_id), [params.event_id]);

  /* ── State ── */
  const [eventLoading, setEventLoading] = useState(true);
  const [eventExists, setEventExists] = useState<boolean | null>(
    // Hydrate from cache immediately if already checked
    _eventCache.has(Number(params.event_id)) ? _eventCache.get(Number(params.event_id))! : null
  );
  const [questions, setQuestions] = useState<FeedbackQuestion[]>([]);
  const [eventName, setEventName] = useState("");
  const [questionsLoading, setQuestionsLoading] = useState(false);

  // question_id → number (rating) | string (text)
  const [answers, setAnswers] = useState<Record<number, number | string>>({});

  const [status, setStatus] = useState<
    "idle" | "loading" | "success" | "error" | "already-submitted"
  >("idle");
  const [errorMsg, setErrorMsg] = useState("");
  const [fingerprint, setFingerprint] = useState<string | null>(null);

  /* ── Helpers ── */
  const setAnswer = (qid: number, val: number | string) => {
    setAnswers((prev) => ({ ...prev, [qid]: val }));
  };

  /* ── 1. Check event — module-level cache prevents double-calls in Strict Mode ── */
  useEffect(() => {
    // Already have result from cache — skip network call
    if (_eventCache.has(EVENT_ID)) {
      setEventExists(_eventCache.get(EVENT_ID)!);
      setEventLoading(false);
      return;
    }

    if (!EVENT_ID || isNaN(EVENT_ID)) {
      _eventCache.set(EVENT_ID, false);
      setEventExists(false);
      setEventLoading(false);
      return;
    }

    let cancelled = false;
    setEventLoading(true);

    api.checkEventExists(EVENT_ID, true)
      .then((ok) => {
        if (cancelled) return;
        _eventCache.set(EVENT_ID, ok);
        setEventExists(ok);
        setEventLoading(false);
      })
      .catch(() => {
        if (cancelled) return;
        _eventCache.set(EVENT_ID, false);
        setEventExists(false);
        setEventLoading(false);
      });

    return () => { cancelled = true; };
  }, [EVENT_ID]);

  /* ── 2. Initialize once event is confirmed — module-level Set prevents re-runs ── */
  useEffect(() => {
    if (!eventExists) return;
    // Already initialized for this event ID (survives Strict Mode remounts)
    if (_initDone.has(EVENT_ID)) return;
    _initDone.add(EVENT_ID);

    let cancelled = false;

    // Fingerprint (non-blocking)
    generateFingerprint()
      .then((fp) => { if (!cancelled) setFingerprint(fp); })
      .catch(() => {});

    // Local duplicate check
    if (hasSubmittedFeedback(EVENT_ID)) {
      setStatus("already-submitted");
    }

    // Fetch questions
    setQuestionsLoading(true);
    getEventQuestions(EVENT_ID)
      .then((qRes) => {
        if (cancelled) return;
        const sorted = [...qRes.questions].sort(
          (a, b) => a.display_order - b.display_order
        );
        setQuestions(sorted);
        setEventName(qRes.event_name);
      })
      .catch(() => { if (!cancelled) setQuestions([]); })
      .finally(() => { if (!cancelled) setQuestionsLoading(false); });

    return () => { cancelled = true; };
  }, [eventExists, EVENT_ID]);

  /* ── Validation ── */
  const getValidationError = (): string | null => {
    for (const q of questions) {
      if (!q.is_required) continue;
      const ans = answers[q.question_id];
      if (
        q.question_type === "rating" &&
        (!ans || typeof ans !== "number" || ans < 1)
      ) {
        return `Please rate question ${q.display_order} before submitting.`;
      }
      if (
        q.question_type === "text" &&
        (!ans || typeof ans !== "string" || !ans.trim())
      ) {
        return `Please answer question ${q.display_order} before submitting.`;
      }
    }
    return null;
  };

  const hasAnyAnswer = questions.some((q) => {
    const a = answers[q.question_id];
    if (q.question_type === "rating") return typeof a === "number" && a > 0;
    return typeof a === "string" && a.trim().length > 0;
  });

  /* ── Submit ── */
  const handleSubmit = async () => {
    const err = getValidationError();
    if (err) {
      setErrorMsg(err);
      setStatus("error");
      setTimeout(() => setStatus("idle"), 4000);
      return;
    }

    setStatus("loading");

    try {
      const feedbackAnswers: FeedbackAnswer[] = questions
        .map((q) => {
          const ans = answers[q.question_id];
          if (
            q.question_type === "rating" &&
            typeof ans === "number" &&
            ans > 0
          ) {
            return { question_id: q.question_id, answer_number: ans };
          }
          if (
            q.question_type === "text" &&
            typeof ans === "string" &&
            ans.trim()
          ) {
            return { question_id: q.question_id, answer_text: ans.trim() };
          }
          return null;
        })
        .filter(Boolean) as FeedbackAnswer[];

      await submitEventAnswers(EVENT_ID, {
        answers: feedbackAnswers,
        device_fingerprint: fingerprint || undefined,
      });

      markFeedbackSubmitted(EVENT_ID);
      setStatus("success");
    } catch (submitErr: unknown) {
      const message =
        submitErr instanceof Error
          ? submitErr.message
          : "Something went wrong.";

      if (message.toLowerCase().includes("already")) {
        markFeedbackSubmitted(EVENT_ID);
        setStatus("already-submitted");
      } else {
        setErrorMsg(message);
        setStatus("error");
        setTimeout(() => setStatus("idle"), 5000);
      }
    }
  };

  /* ═════════════════════════ RENDER ═════════════════════════════ */

  return (
    <div className="min-h-screen flex flex-col bg-gradient-to-br from-slate-50 via-purple-50/30 to-blue-50/40 relative overflow-hidden">
      {/* Ambient blobs */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden">
        <div className="absolute -top-40 -right-40 w-96 h-96 bg-purple-200/30 rounded-full blur-3xl" />
        <div className="absolute -bottom-40 -left-40 w-96 h-96 bg-blue-200/30 rounded-full blur-3xl" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-pink-100/20 rounded-full blur-3xl" />
      </div>

      <main className="flex-1 relative z-10 flex items-center justify-center px-4 py-10 md:py-16">
        <AnimatePresence mode="wait">
          {/* ─── Loading ─── */}
          {(eventLoading || (eventExists && questionsLoading)) && (
            <motion.div
              key="loading"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="w-full max-w-xl"
            >
              <div className="relative bg-white/70 backdrop-blur-xl rounded-3xl shadow-2xl shadow-purple-200/30 border border-white/60 overflow-hidden">
                <div className="absolute top-0 left-0 right-0 h-1.5 bg-gradient-to-r from-violet-500 via-purple-500 to-pink-500" />
                <div className="p-8 md:p-10 flex flex-col items-center justify-center py-20">
                  <Loader2 className="w-10 h-10 text-violet-500 animate-spin mb-4" />
                  <p className="text-sm text-gray-500 font-medium">
                    {eventLoading
                      ? "Checking event availability..."
                      : "Loading questions..."}
                  </p>
                </div>
              </div>
            </motion.div>
          )}

          {/* ─── Event Not Available ─── */}
          {!eventLoading && !eventExists && (
            <motion.div
              key="not-found"
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
              transition={{ duration: 0.5, ease: "easeOut" }}
              className="w-full max-w-xl"
            >
              <div className="relative bg-white/70 backdrop-blur-xl rounded-3xl shadow-2xl shadow-purple-200/30 border border-white/60 overflow-hidden">
                <div className="absolute top-0 left-0 right-0 h-1.5 bg-gradient-to-r from-gray-400 via-gray-500 to-gray-400" />
                <div className="p-8 md:p-10 text-center">
                  <motion.div
                    initial={{ scale: 0 }}
                    animate={{ scale: 1 }}
                    transition={{
                      type: "spring",
                      stiffness: 300,
                      damping: 20,
                      delay: 0.1,
                    }}
                    className="inline-flex items-center justify-center w-20 h-20 rounded-full bg-gradient-to-br from-gray-300 to-gray-400 mb-5 shadow-lg shadow-gray-200/50"
                  >
                    <CalendarOff className="w-10 h-10 text-white" />
                  </motion.div>
                  <motion.h2
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.2 }}
                    className="text-2xl font-bold text-gray-900 mb-2"
                  >
                    Feedback Unavailable
                  </motion.h2>
                  <motion.p
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.3 }}
                    className="text-gray-500 text-sm max-w-xs mx-auto mb-2"
                  >
                    This event is either not active or doesn&apos;t exist.
                    Feedback collection is currently closed.
                  </motion.p>
                  <motion.p
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ delay: 0.4 }}
                    className="text-xs text-gray-400"
                  >
                    If you believe this is an error, please contact the event
                    organizer.
                  </motion.p>
                  <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ delay: 0.5 }}
                    className="mt-8"
                  >
                    <Link
                      href="/"
                      className="inline-flex items-center gap-2 px-6 py-3 rounded-2xl bg-gradient-to-r from-violet-600 to-purple-600 text-white text-sm font-bold shadow-lg shadow-violet-300/40 hover:from-violet-700 hover:to-purple-700 transition-all"
                    >
                      <ArrowLeft className="w-4 h-4" />
                      Back to Home
                    </Link>
                  </motion.div>
                </div>
              </div>
            </motion.div>
          )}

          {/* ─── Feedback Form ─── */}
          {!eventLoading && eventExists && !questionsLoading && (
            <motion.div
              key="form"
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
              transition={{ duration: 0.6, ease: "easeOut" }}
              className="w-full max-w-xl"
            >
              <div className="relative bg-white/70 backdrop-blur-xl rounded-3xl shadow-2xl shadow-purple-200/30 border border-white/60 overflow-hidden">
                <div className="absolute top-0 left-0 right-0 h-1.5 bg-gradient-to-r from-violet-500 via-purple-500 to-pink-500" />

                <div className="p-6 md:p-10">
                  {/* Header */}
                  <motion.div
                    className="text-center mb-8"
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.1 }}
                  >
                    <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-gradient-to-r from-violet-100 to-purple-100 border border-violet-200/50 mb-4">
                      <MessageSquareHeart className="w-4 h-4 text-violet-600" />
                      <span className="text-xs font-semibold text-violet-700 tracking-wide uppercase">
                        Anonymous Feedback
                      </span>
                    </div>

                    {eventName && (
                      <p className="text-xs font-medium text-violet-500 mb-1">
                        {eventName}
                      </p>
                    )}

                    <h1 className="text-2xl md:text-3xl font-extrabold text-gray-900 leading-tight">
                      How was your{" "}
                      <span className="bg-gradient-to-r from-violet-600 to-purple-600 bg-clip-text text-transparent">
                        experience?
                      </span>
                    </h1>
                    <p className="mt-2 text-sm text-gray-500 max-w-xs mx-auto">
                      Your honest feedback helps us improve future events.
                      Completely anonymous &amp; secure.
                    </p>
                  </motion.div>

                  {/* ─── States ─── */}
                  <AnimatePresence mode="wait">
                    {/* SUCCESS */}
                    {status === "success" && (
                      <motion.div
                        key="success"
                        initial={{ opacity: 0, scale: 0.9 }}
                        animate={{ opacity: 1, scale: 1 }}
                        exit={{ opacity: 0, scale: 0.9 }}
                        className="text-center py-8 relative"
                      >
                        <motion.div
                          initial={{ scale: 0 }}
                          animate={{ scale: 1 }}
                          transition={{
                            type: "spring",
                            stiffness: 300,
                            damping: 15,
                            delay: 0.1,
                          }}
                          className="inline-flex items-center justify-center w-20 h-20 rounded-full bg-gradient-to-br from-green-400 to-emerald-500 mb-5 shadow-lg shadow-green-200/50"
                        >
                          <CheckCircle2 className="w-10 h-10 text-white" />
                        </motion.div>
                        <h2 className="text-2xl font-bold text-gray-900 mb-2">
                          Thank You! 🎉
                        </h2>
                        <p className="text-gray-500 text-sm">
                          Your feedback has been submitted successfully.
                        </p>

                        {/* Confetti */}
                        {Array.from({ length: 20 }).map((_, i) => (
                          <motion.div
                            key={`c-${i}`}
                            className="absolute rounded-full pointer-events-none"
                            style={{
                              width: 4 + Math.random() * 8,
                              height: 4 + Math.random() * 8,
                              backgroundColor: [
                                "#8b5cf6",
                                "#22c55e",
                                "#eab308",
                                "#ef4444",
                                "#3b82f6",
                                "#ec4899",
                              ][i % 6],
                              left: `${10 + Math.random() * 80}%`,
                              top: `${10 + Math.random() * 30}%`,
                            }}
                            initial={{ opacity: 0, y: 0, scale: 0 }}
                            animate={{
                              opacity: [0, 1, 0],
                              y: [0, -80 - Math.random() * 80],
                              x: [(Math.random() - 0.5) * 80],
                              scale: [0, 1, 0.4],
                            }}
                            transition={{
                              duration: 1.4 + Math.random(),
                              delay: i * 0.04,
                              ease: "easeOut",
                            }}
                          />
                        ))}
                      </motion.div>
                    )}

                    {/* ALREADY SUBMITTED */}
                    {status === "already-submitted" && (
                      <motion.div
                        key="already"
                        initial={{ opacity: 0, scale: 0.9 }}
                        animate={{ opacity: 1, scale: 1 }}
                        exit={{ opacity: 0, scale: 0.9 }}
                        className="text-center py-8"
                      >
                        <motion.div
                          initial={{ scale: 0 }}
                          animate={{ scale: 1 }}
                          transition={{
                            type: "spring",
                            stiffness: 300,
                            damping: 15,
                          }}
                          className="inline-flex items-center justify-center w-20 h-20 rounded-full bg-gradient-to-br from-amber-400 to-orange-500 mb-5 shadow-lg shadow-amber-200/50"
                        >
                          <ShieldCheck className="w-10 h-10 text-white" />
                        </motion.div>
                        <h2 className="text-2xl font-bold text-gray-900 mb-2">
                          Already Submitted
                        </h2>
                        <p className="text-gray-500 text-sm max-w-xs mx-auto">
                          You&apos;ve already shared your feedback for this
                          event. You can submit again after 24 hours.
                        </p>
                      </motion.div>
                    )}

                    {/* FORM */}
                    {(status === "idle" ||
                      status === "loading" ||
                      status === "error") && (
                      <motion.div
                        key="questions-form"
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                      >
                        {questions.length === 0 ? (
                          <div className="text-center py-8 text-gray-500 text-sm">
                            No questions available for this event yet.
                          </div>
                        ) : (
                          <div className="space-y-5 mb-6">
                            {questions.map((q, idx) =>
                              q.question_type === "rating" ? (
                                <RatingQuestionCard
                                  key={q.question_id}
                                  question={q}
                                  value={
                                    (answers[q.question_id] as number) || 0
                                  }
                                  onChange={(v) =>
                                    setAnswer(q.question_id, v)
                                  }
                                  disabled={status === "loading"}
                                  index={idx}
                                />
                              ) : (
                                <TextQuestionCard
                                  key={q.question_id}
                                  question={q}
                                  value={
                                    (answers[q.question_id] as string) || ""
                                  }
                                  onChange={(v) =>
                                    setAnswer(q.question_id, v)
                                  }
                                  disabled={status === "loading"}
                                  index={idx}
                                />
                              )
                            )}
                          </div>
                        )}

                        {/* Error */}
                        <AnimatePresence>
                          {status === "error" && (
                            <motion.div
                              initial={{ opacity: 0, height: 0 }}
                              animate={{ opacity: 1, height: "auto" }}
                              exit={{ opacity: 0, height: 0 }}
                              className="mb-4 flex items-center gap-2 px-4 py-3 rounded-xl bg-red-50 border border-red-200 text-sm text-red-700"
                            >
                              <AlertTriangle className="w-4 h-4 flex-shrink-0" />
                              <span>{errorMsg}</span>
                            </motion.div>
                          )}
                        </AnimatePresence>

                        {/* Submit button */}
                        <motion.button
                          onClick={handleSubmit}
                          disabled={status === "loading" || !hasAnyAnswer}
                          className={`w-full py-4 rounded-2xl font-bold text-white text-sm tracking-wide transition-all duration-300 flex items-center justify-center gap-2 ${
                            !hasAnyAnswer
                              ? "bg-gray-300 cursor-not-allowed"
                              : status === "loading"
                                ? "bg-violet-400 cursor-wait"
                                : "bg-gradient-to-r from-violet-600 to-purple-600 hover:from-violet-700 hover:to-purple-700 shadow-lg shadow-violet-300/40 hover:shadow-violet-400/50"
                          }`}
                          whileHover={
                            hasAnyAnswer && status !== "loading"
                              ? { scale: 1.02 }
                              : {}
                          }
                          whileTap={
                            hasAnyAnswer && status !== "loading"
                              ? { scale: 0.98 }
                              : {}
                          }
                        >
                          {status === "loading" ? (
                            <>
                              <Loader2 className="w-5 h-5 animate-spin" />
                              Submitting...
                            </>
                          ) : (
                            <>
                              <Send className="w-4 h-4" />
                              Submit Feedback
                            </>
                          )}
                        </motion.button>

                        {/* Security badge */}
                        <motion.div
                          initial={{ opacity: 0 }}
                          animate={{ opacity: 1 }}
                          transition={{ delay: 0.4 }}
                          className="mt-4 flex items-center justify-center gap-1.5 text-[11px] text-gray-400"
                        >
                          <ShieldCheck className="w-3.5 h-3.5" />
                          <span>Anonymous &amp; Spam-Protected</span>
                          <span className="mx-1">•</span>
                          <Sparkles className="w-3.5 h-3.5" />
                          <span>No login required</span>
                        </motion.div>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </div>
              </div>

              {/* Back link */}
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.6 }}
                className="mt-6 text-center"
              >
                <Link
                  href="/"
                  className="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-violet-600 transition-colors"
                >
                  <ArrowLeft className="w-4 h-4" />
                  Back to Home
                </Link>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>
      </main>
    </div>
  );
}
