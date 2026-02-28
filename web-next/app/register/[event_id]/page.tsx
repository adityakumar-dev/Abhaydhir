"use client";

import { useState, useEffect, useRef, useMemo } from "react";
import {
  ArrowLeft,
  Download,
} from "lucide-react";
import Link from "next/link";
import { api } from "@/services/api";
import { Spinner } from "@/components/ui/spinner";
import { useRouter } from "next/navigation";
import LoadingOverlay from "@/components/LoadingOverlay";
import { Toast } from "@/components/ui/toast";
import DownloadCardPopup from "@/components/download_card";

interface TouristRegistrationResponse {
  message: string;
  tourist: {
    user_id: number;
    name: string;
    phone: string;
    unique_id_type: string;
    unique_id: string;
    is_group: boolean;
    group_count: number;
    registered_event_id: number;
    valid_date : string;
  };
  meta: {
    user_id: number;
    qr_code: string;
    image_path: string;
  } | null;
  visitor_card_url: string | null;
}

export default function RegisterPage({ params }: { params: { event_id: string } }) {
  const router = useRouter();
  const event_id = useMemo(() => Number(params?.event_id), [params?.event_id]);
  const [eventExists, setEventExists] = useState<boolean | null>(null);
  const eventCheckRef = useRef(false);

  // Check if the event exists on component mount
  useEffect(() => {
    if (eventCheckRef.current) return;
    eventCheckRef.current = true;

    const checkEvent = async () => {
      if (!event_id || isNaN(event_id)) {
        setEventExists(false);
        return;
      }
      const exists = await api.checkEventExists(event_id);
      setEventExists(exists);
    };
    checkEvent();
  }, [event_id]);

  const [formData, setFormData] = useState({
    fullName: "",
    phone: "",
    is_group: false,
    group_count: 1,
    photo: null as File | null,
    unique_id_photo: null as File | null,
    valid_date: "",
  });

  const [isLoading, setIsLoading] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [loadingMessage, setLoadingMessage] = useState("");
  const [isLoadingOverlayOpen, setIsLoadingOverlayOpen] = useState(false);

  const [toast, setToast] = useState<{ message: string; type: 'success' | 'error' } | null>(null);
  const [isDownloadPopupOpen, setIsDownloadPopupOpen] = useState(false);
  const [downloadCardPath, setDownloadCardPath] = useState<string | null>(null);

  const handleInputChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>
  ) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      setFormData({ ...formData, photo: e.target.files[0] });
    }
  };

  const handleUniqueIdPhotoChange = (
    e: React.ChangeEvent<HTMLInputElement>
  ) => {
    if (e.target.files && e.target.files[0]) {
      setFormData({ ...formData, unique_id_photo: e.target.files[0] });
    }
  };

  const showToast = (message: string, type: 'success' | 'error') => {
    setToast({ message, type });
  };

  const handleSubmit = async () => {
    setIsSubmitting(true);
    setIsLoadingOverlayOpen(true);
    setLoadingMessage("Registering tourist...");
    try {
      // Validate required fields
      if (!formData.photo) {
        showToast("Please upload a valid profile photo.", "error");
        return;
      }
      if (!formData.unique_id_photo) {
        showToast("Please upload a valid ID photo.", "error");
        return;
      }
      if (!formData.fullName) {
        showToast("Please enter your full name", "error");
        return;
      }
      if (!formData.valid_date) {
        showToast("Please select your entry date", "error");
        return;
      }
      if (!formData.phone) {
        showToast("Please enter a valid phone", "error");
        return;
      }
      if (formData.is_group && formData.group_count < 2) {
        showToast("Group size must be at least 2 people", "error");
        return;
      }
      // Check if email exists
      //  setLoadingMessage("Validating registration details...");
      // Call API to register tourist
      const registrationPayload = {
        name: formData.fullName.trim(),
        phone: formData.phone,
        is_group: formData.is_group,
        group_count: formData.group_count,
        registered_event_id: event_id,
        valid_date: formData.valid_date,

        photo: formData.photo as File,
        unique_id_photo: formData.unique_id_photo as File,
      };
      console.log("Submitting registration with payload:", registrationPayload);
      const parsedData = await api.registerTourist(registrationPayload);
      console.log("Registration response:", parsedData);
      console.log("Visitor card URL from backend:", parsedData.visitor_card_url);
      
      if (parsedData.visitor_card_url) {
        // Store the visitor card URL for download/preview
        const fullCardUrl = api.getVisitorCardUrl(parsedData.visitor_card_url);
        console.log("Full card URL:", fullCardUrl);
        setDownloadCardPath(fullCardUrl);
        api.latest_visitor_card = parsedData.visitor_card_url;
        setIsDownloadPopupOpen(true);
      }
      
      showToast("Tourist registration successful! Check your phone for the sms", "success");
    } catch (error: any) {
      showToast(error?.message || "Registration failed", "error");
    } finally {
      setIsSubmitting(false);
      setIsLoadingOverlayOpen(false);
    }
  };

  const renderStep = () => {
    if (eventExists === null) {
      return <Spinner />;
    }
    if (eventExists === false) {
      return (
        <div className="p-12 text-center">
          <div className="mb-4">
            <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-red-100 mb-4">
              <svg className="w-8 h-8 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4v.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
          </div>
          <h2 className="text-2xl font-bold text-red-600 mb-3">Invalid or Inactive Event</h2>
          <p className="text-gray-600">The event you are trying to register for does not exist or is not active.</p>
        </div>
      );
    }

    if (isLoading) {
      return <Spinner />;
    }

    return (
      <div className="space-y-6">
        <div className="text-center space-y-2 mb-8">
          <h1 className="text-4xl sm:text-3xl font-bold bg-gradient-to-r from-yellow-600 to-orange-600 bg-clip-text text-transparent">
            Tourist Registration
          </h1>
          <p className="text-gray-600 font-medium">Spring Festival 2026</p>
        </div>
        <div className="bg-gradient-to-r from-amber-50 via-orange-50 to-yellow-50 border-2 border-yellow-200 rounded-xl p-5 shadow-sm">
          <div className="flex gap-3">
            <div className="flex-shrink-0">
              <svg className="w-5 h-5 text-yellow-700 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M18 5v8a2 2 0 01-2 2h-5l-5 4v-4H4a2 2 0 01-2-2V5a2 2 0 012-2h12a2 2 0 012 2z" clipRule="evenodd" />
              </svg>
            </div>
            <div className="text-sm text-yellow-800">
              <p className="font-semibold mb-1">Welcome, Tourist!</p>
              <p>Register to receive your digital visitor card with QR code. We'll send you a welcome SMS with your entry pass.</p>
            </div>
          </div>
        </div>
        
        <div className="space-y-5">
          <div className="space-y-3">
            <label className="block text-sm font-semibold text-gray-800">
              Full Name <span className="text-red-500">*</span>
            </label>
            <input
              name="fullName"
              value={formData.fullName}
              onChange={handleInputChange}
              className="w-full px-4 py-3 rounded-lg border-2 border-gray-200 focus:border-yellow-500 focus:ring-2 focus:ring-yellow-200 outline-none transition-all"
              placeholder="Enter your full name"
              autoComplete="name"
            />
          </div>
          <div className="space-y-3">
            <label className="block text-sm font-semibold text-gray-800">
              Your Entry Date <span className="text-red-500">*</span>
            </label>
            <div className="flex gap-3 flex-wrap">
              {[ "2026-02-28", "2026-03-01"].map((date) => (
                <button
                  key={date}
                  type="button"
                  className={`flex-1 min-w-[100px] px-4 py-3 rounded-lg border-2 transition-all font-semibold text-sm ${
                    formData.valid_date === date
                      ? "bg-gradient-to-br from-yellow-500 to-orange-500 text-white border-yellow-600 shadow-lg shadow-yellow-300/50"
                      : "bg-white text-gray-700 border-gray-200 hover:border-yellow-400 hover:bg-yellow-50"
                  }`}
                  onClick={() => setFormData({ ...formData, valid_date: date })}
                >
                  {date === "2026-02-28" && "28 Feb"}
                  {date === "2026-03-01" && "1 Mar"}
                </button>
              ))}
            </div>
          </div>
          <div className="space-y-3">
            <label className="block text-sm font-semibold text-gray-800">
              Phone Number <span className="text-red-500">*</span>
            </label>
            <input
              type="tel"
              name="phone"
              inputMode="numeric"
              maxLength={10}
              value={formData.phone}
              onChange={(e) => {
                const digits = e.target.value.replace(/\D/g, "");
                setFormData({ ...formData, phone: digits });
              }}
              className="w-full px-4 py-3 rounded-lg border-2 border-gray-200 focus:border-yellow-500 focus:ring-2 focus:ring-yellow-200 outline-none transition-all"
              placeholder="Enter 10-digit phone number"
            />
          </div>
        </div>

        <div className="space-y-5 pt-2">
          <div className="space-y-3">
            <label className="block text-sm font-semibold text-gray-800">
              Registration Type <span className="text-red-500">*</span>
            </label>
            <div className="grid grid-cols-2 gap-3">
              {[
                { value: false, label: "Individual", icon: "👤" },
                { value: true, label: "Group", icon: "👥" }
              ].map((type) => (
                <button
                  key={type.value.toString()}
                  type="button"
                  className={`p-4 rounded-lg border-2 cursor-pointer transition-all ${
                    formData.is_group === type.value
                      ? "bg-yellow-100 border-yellow-500 shadow-lg shadow-yellow-200/50"
                      : "bg-white border-gray-200 hover:border-yellow-300"
                  }`}
                  onClick={() => setFormData({
                    ...formData,
                    is_group: type.value,
                    group_count: type.value ? Math.max(2, formData.group_count) : 1
                  })}
                >
                  <div className="text-2xl mb-2">{type.icon}</div>
                  <div className="text-sm font-semibold text-gray-800">{type.label}</div>
                </button>
              ))}
            </div>
          </div>

          {formData.is_group && (
            <div className="space-y-4 p-4 bg-blue-50 border-2 border-blue-200 rounded-lg">
              <div className="space-y-3">
                <label className="block text-sm font-semibold text-gray-800">
                  Number of People <span className="text-red-500">*</span>
                </label>
                <input
                  type="number"
                  name="group_count"
                  value={formData.group_count}
                  onChange={handleInputChange}
                  min="2"
                  className="w-full px-4 py-3 rounded-lg border-2 border-blue-200 focus:border-yellow-500 focus:ring-2 focus:ring-yellow-200 outline-none transition-all"
                  placeholder="Minimum 2 people"
                />
              </div>
              <p className="text-sm text-blue-700 flex gap-2">
                <svg className="w-5 h-5 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M18 5v8a2 2 0 01-2 2h-5l-5 4v-4H4a2 2 0 01-2-2V5a2 2 0 012-2h12a2 2 0 012 2z" clipRule="evenodd" />
                </svg>
                <span>The group leader's details will be used for the visitor card.</span>
              </p>
            </div>
          )}
        </div>

        <div className="space-y-5 pt-2">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-3">
              <label className="block text-sm font-semibold text-gray-800">
                Profile Photo <span className="text-red-500">*</span>
              </label>
              <div className="relative">
                <input
                  type="file"
                  name="photo"
                  accept="image/*"
                  onChange={handleFileChange}
                  className="hidden"
                  id="profile-photo"
                />
                <label
                  htmlFor="profile-photo"
                  className="flex items-center justify-center w-full h-48 rounded-lg border-2 border-dashed border-yellow-300 bg-yellow-50 cursor-pointer hover:bg-yellow-100 transition-all overflow-hidden relative"
                >
                  {formData.photo ? (
                    <>
                      <img
                        src={URL.createObjectURL(formData.photo)}
                        alt="Profile preview"
                        className="w-full h-full object-cover blur-sm"
                      />
                      <div className="absolute inset-0 flex items-center justify-center">
                        <div className="bg-white/95 px-6 py-2 rounded-lg font-semibold text-yellow-700 shadow-lg">
                          Change Photo
                        </div>
                      </div>
                    </>
                  ) : (
                    <div className="text-center">
                      <svg className="mx-auto h-8 w-8 text-yellow-600 mb-2" stroke="currentColor" fill="none" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                      <p className="text-sm font-semibold text-yellow-900">Click to upload</p>
                      <p className="text-xs text-yellow-700 mt-1">JPG, PNG • Max 5MB</p>
                    </div>
                  )}
                </label>
              </div>
              <p className="text-xs text-gray-600">
                📸 Upload a clear, well-lit frontal photo. Make sure your face is visible and not blocked.
              </p>
            </div>
            <div className="space-y-3">
              <label className="block text-sm font-semibold text-gray-800">
                Unique ID Photo <span className="text-red-500">*</span>
              </label>
              <div className="relative">
                <input
                  type="file"
                  name="unique_id_photo"
                  accept="image/*"
                  onChange={handleUniqueIdPhotoChange}
                  className="hidden"
                  id="id-photo"
                />
                <label
                  htmlFor="id-photo"
                  className="flex items-center justify-center w-full h-48 rounded-lg border-2 border-dashed border-orange-300 bg-orange-50 cursor-pointer hover:bg-orange-100 transition-all overflow-hidden relative"
                >
                  {formData.unique_id_photo ? (
                    <>
                      <img
                        src={URL.createObjectURL(formData.unique_id_photo)}
                        alt="ID preview"
                        className="w-full h-full object-cover blur-sm"
                      />
                      <div className="absolute inset-0 flex items-center justify-center">
                        <div className="bg-white/95 px-6 py-2 rounded-lg font-semibold text-orange-700 shadow-lg">
                          Change Photo
                        </div>
                      </div>
                    </>
                  ) : (
                    <div className="text-center">
                      <svg className="mx-auto h-8 w-8 text-orange-600 mb-2" stroke="currentColor" fill="none" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H5a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-5m-4 0V5a2 2 0 10-4 0v5m0 0H5" />
                      </svg>
                      <p className="text-sm font-semibold text-orange-900">Click to upload</p>
                      <p className="text-xs text-orange-700 mt-1">JPG, PNG • Max 5MB</p>
                    </div>
                  )}
                </label>
              </div>
              <p className="text-xs text-gray-600">
                🆔 Upload a clear photo of your ID (Aadhar, Passport, College ID, or other valid ID).
              </p>
            </div>
          </div>
          <div className="bg-amber-50 border-l-4 border-amber-500 p-4 rounded">
            <p className="text-sm text-amber-800 font-medium">
              ✓ Make sure your photos are clear, well-lit, and unblocked
            </p>
          </div>

          <button
            onClick={handleSubmit}
            disabled={isSubmitting}
            className="w-full bg-gradient-to-r from-yellow-500 to-orange-500 hover:from-yellow-600 hover:to-orange-600 disabled:from-yellow-300 disabled:to-orange-300 text-white font-bold px-6 py-4 rounded-lg shadow-lg shadow-yellow-200/50 transition-all disabled:cursor-not-allowed flex items-center justify-center gap-2 text-lg"
          >
            {isSubmitting ? (
              <>
                <Spinner />
                <span>Registering...</span>
              </>
            ) : (
              <>
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                Complete Registration
              </>
            )}
          </button>
          {downloadCardPath && (
            <div className="mt-6">
              <Link
                href={downloadCardPath}
                target="_blank"
                className="w-full flex items-center justify-center gap-3 bg-gradient-to-r from-green-50 to-emerald-50 text-green-700 border-2 border-green-300 px-6 py-4 rounded-lg hover:from-green-100 hover:to-emerald-100 transition-all font-semibold shadow-lg shadow-green-200/50"
              >
                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M2 9.5A6.5 6.5 0 1115.5 9 6.5 6.5 0 012 9.5zm10.5 2.25a1.5 1.5 0 11-3 0 1.5 1.5 0 013 0zm-1.5-7a2 2 0 100-4 2 2 0 000 4z" />
                </svg>
                <span>Download Your Entry Pass</span>
                <Download className="w-4 h-4" />
              </Link>
            </div>
          )}
        </div>
      </div>
    );
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-yellow-50 via-orange-50 to-amber-50 py-8 sm:py-16">
      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}
      <LoadingOverlay isOpen={isLoadingOverlayOpen} message={loadingMessage} />
      <div className="container mx-auto px-4 sm:px-6">
        <Link
          href="/"
          className="inline-flex items-center text-yellow-700 hover:text-yellow-800 font-semibold mb-8 transition-colors"
        >
          <ArrowLeft className="w-5 h-5 mr-2" />
          Back to Home
        </Link>

        <div className="max-w-2xl mx-auto">
          <div className="bg-white rounded-2xl shadow-2xl p-4 sm:p-8">
            {renderStep()}
          </div>

          {/* Footer Info */}
          <div className="mt-8 text-center text-sm text-gray-600">
            <p>Your data is secure and will only be used for festival registration.</p>
          </div>
        </div>

        {downloadCardPath && (
          <DownloadCardPopup
            cardPath={downloadCardPath}
            isOpen={isDownloadPopupOpen}
            onClose={() => setIsDownloadPopupOpen(false)}
          />
        )}
      </div>
    </div>
  );
}