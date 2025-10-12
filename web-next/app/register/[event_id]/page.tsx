"use client";

import { useState, useEffect } from "react";
import {
  ArrowLeft,
  Download,
} from "lucide-react";
import Link from "next/link";
import { api } from "@/services/api";
import { Spinner } from "@/components/ui/spinner";
import router, { useRouter } from "next/navigation";
import LoadingOverlay from "@/components/LoadingOverlay";
import { Toast } from "@/components/ui/toast";
import DownloadCardPopup from "@/components/download_card";

interface TouristRegistrationResponse {
  message: string;
  tourist: {
    user_id: number;
    name: string;
    email: string;
    unique_id_type: string;
    unique_id: string;
    is_group: boolean;
    group_count: number;
    registered_event_id: number;
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
  const event_id = Number(params?.event_id);
  const [eventExists, setEventExists] = useState<boolean | null>(null);

  // Check if the event exists on component mount
  useEffect(() => {
    console.log("Checking event ID:", event_id);
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
    firstName: "",
    lastName: "",
    email: "",
    unique_id_type: "aadhar",
    unique_id: "",
    is_group: false,
    group_count: 1,
    photo: null as File | null,
  });

  const [isLoading, setIsLoading] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [loadingMessage, setLoadingMessage] = useState("");
  const [isLoadingOverlayOpen, setIsLoadingOverlayOpen] = useState(false);

  const [toast, setToast] = useState<{ message: string; type: 'success' | 'error' } | null>(null);
  const [download,setDownload] = useState<boolean>(false)
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
      if (!formData.unique_id_type) {
        showToast("Please select a valid ID type", "error");
        return;
      }
      if (!formData.unique_id) {
        showToast("Please enter a valid ID number", "error");
        return;
      }
      if (!formData.firstName) {
        showToast("Please enter a valid first name", "error");
        return;
      }
      if (!formData.email) {
        showToast("Please enter a valid email", "error");
        return;
      }
      if (formData.is_group && formData.group_count < 2) {
        showToast("Group size must be at least 2 people", "error");
        return;
      }
      // Check if email exists
       setLoadingMessage("Validating registration details...");
      // Call API to register tourist
      const registrationPayload = {
        name: `${formData.firstName} ${formData.lastName}`.trim(),
        email: formData.email,
        unique_id_type: formData.unique_id_type,
        unique_id: formData.unique_id,
        is_group: formData.is_group,
        group_count: formData.group_count,
        registered_event_id: event_id,
        photo: formData.photo as File,
      };
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
      
      showToast("Tourist registration successful! Check your email for the visitor card.", "success");
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
        <div className="p-8 text-center">
          <h2 className="text-xl font-bold text-red-600 mb-4">Invalid or inactive event</h2>
          <p className="text-gray-700">The event you are trying to register for does not exist or is not active.</p>
        </div>
      );
    }

    if (isLoading) {
      return <Spinner />;
    }

    return (
      <div className="space-y-4 sm:space-y-6">
        <div className="flex items-center justify-center">
          <h1 className="text-2xl font-bold">Tourist Registration - Spring Festival 2025</h1>
        </div>
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <p className="text-sm text-blue-700">
            Register as a tourist to receive your visitor card with QR code. 
            A welcome email with your visitor card will be sent to your registered email address.
          </p>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 sm:gap-6">
          <div className="space-y-2">
            <label className="text-sm font-medium text-gray-700">
              First Name
            </label>
            <input
              name="firstName"
              value={formData.firstName}
              onChange={handleInputChange}
              className="w-full px-4 py-3 rounded-lg border focus:ring-2 focus:ring-yellow-200 focus:border-yellow-400"
              placeholder="Enter first name"
            />
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium text-gray-700">
              Last Name
            </label>
            <input
              name="lastName"
              value={formData.lastName}
              onChange={handleInputChange}
              className="w-full px-4 py-3 rounded-lg border focus:ring-2 focus:ring-yellow-200 focus:border-yellow-400"
              placeholder="Enter last name"
            />
          </div>
        </div>
        <div className="space-y-2">
          <label className="text-sm font-medium text-gray-700">Email</label>
          <input
            type="email"
            name="email"
            value={formData.email}
            onChange={handleInputChange}
            className="w-full px-4 py-3 rounded-lg border focus:ring-2 focus:ring-yellow-200 focus:border-yellow-400"
            placeholder="Enter email"
          />
        </div>
        <div className="space-y-4">
          <label className="text-sm font-medium text-gray-700">
            ID Type
          </label>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 sm:gap-4">
            {["aadhar", "passport", "college_id", "other"].map((type) => (
              <div
                key={type}
                className={`flex items-center justify-center p-3 rounded-lg cursor-pointer transition-all ${
                  formData.unique_id_type === type
                    ? "bg-yellow-100 border-2 border-yellow-600"
                    : "bg-gray-50 border-2 border-transparent hover:bg-yellow-50"
                }`}
                onClick={() => setFormData({ ...formData, unique_id_type: type })}
              >
                <input
                  type="radio"
                  className="hidden"
                  name="idType"
                  value={type}
                  checked={formData.unique_id_type === type}
                  onChange={() => {}}
                />
                <label className="cursor-pointer capitalize">
                  {type.replace("_", " ")}
                </label>
              </div>
            ))}
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium text-gray-700">
              {formData.unique_id_type.replace("_", " ").charAt(0).toUpperCase() + 
               formData.unique_id_type.replace("_", " ").slice(1)} Number
            </label>
            <div className="relative">
              <input
                name="unique_id"
                value={formData.unique_id}
                maxLength={
                  formData.unique_id_type === "aadhar" ? 12 :
                  formData.unique_id_type === "passport" ? 10 :
                  undefined
                }
                onChange={handleInputChange}
                className="w-full px-4 py-3 rounded-lg border focus:ring-2 focus:ring-yellow-200 focus:border-yellow-400"
                placeholder={`Enter ${formData.unique_id_type.replace("_", " ")} number`}
              />
            </div>
          </div>
          <div className="space-y-6">
            <div className="space-y-4">
              <label className="text-sm font-medium text-gray-700">
                Registration Type
              </label>
              <div className="grid grid-cols-2 gap-2 sm:gap-4">
                {[
                  { value: false, label: "Individual" },
                  { value: true, label: "Group Registration" }
                ].map((type) => (
                  <div
                    key={type.value.toString()}
                    className={`flex items-center justify-center p-3 rounded-lg cursor-pointer transition-all ${
                      formData.is_group === type.value
                        ? "bg-yellow-100 border-2 border-yellow-600"
                        : "bg-gray-50 border-2 border-transparent hover:bg-yellow-50"
                    }`}
                    onClick={() => setFormData({ 
                      ...formData, 
                      is_group: type.value,
                      group_count: type.value ? Math.max(2, formData.group_count) : 1
                    })}
                  >
                    <input
                      type="radio"
                      className="hidden"
                      name="registrationType"
                      value={type.value.toString()}
                      checked={formData.is_group === type.value}
                      onChange={() => {}}
                    />
                    <label className="cursor-pointer">
                      {type.label}
                    </label>
                  </div>
                ))}
              </div>

              {formData.is_group && (
                <>
                  <div className="space-y-2">
                    <label className="text-sm font-medium text-gray-700">
                      Number of People in Group (minimum 2)
                    </label>
                    <input
                      type="number"
                      name="group_count"
                      value={formData.group_count}
                      onChange={handleInputChange}
                      min="2"
                      className="w-full px-4 py-3 rounded-lg border focus:ring-2 focus:ring-yellow-200 focus:border-yellow-400"
                      placeholder="Enter number of people"
                    />
                  </div>
                  <div className="space-y-2">
                    <p className="text-sm text-gray-600">
                      Note: This registration covers all members of your group. The group leader's photo and details will be used for the visitor card.
                    </p>
                  </div>
                </>
              )}
            </div>
          </div>
          <div className="space-y-6">
            <div className="space-y-2">
              <label className="text-sm font-medium text-gray-700">
                Profile Photo
              </label>
              <input
                type="file"
                name="photo"
                accept="image/*"
                onChange={handleFileChange}
                className="w-full px-4 py-3 rounded-lg border focus:ring-2 focus:ring-yellow-200 focus:border-yellow-400"
              />
            </div>
            <div>
              <p>
               NOTE : "Please upload valid and latest profile picture"
              </p>
            </div>
            {/* <div>
              <p>NOTE : "If your registration failed please switch to chrome browser or device and try again"</p>
            </div> */}
        {/* <div className="flex items-center justify-center">
          <h2 className="text-xl sm:text-sm font-semibold "></h2>
        </div> */}
            <button
              onClick={handleSubmit}
              disabled={isSubmitting}
              className="w-full bg-yellow-600 text-white px-6 py-3 rounde-lg hover:bg-yellow-700 transition-colors disabled:bg-yellow-400 disabled:cursor-not-allowed flex items-center justify-center"
            >
              {isSubmitting ? (
                <>
                  <Spinner />
                  <span className="ml-2">Registering Tourist...</span>
                </>
              ) : (
                "Complete Tourist Registration"
              )}
            </button>
            {downloadCardPath && (
            <div className="mt-4">
              <Link 
                href={downloadCardPath} 
                target="_blank"
                className="w-full flex items-center justify-center gap-2 bg-yellow-100 text-yellow-600 px-6 py-3 rounded-lg hover:bg-yellow-200 transition-colors"
              >
                <Download className="w-4 h-4" />
                Download Your Entry Pass
              </Link>
            </div>
            )}

          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-yellow-50 to-white py-6 sm:py-12">
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
          className="inline-flex items-center text-yellow-600 hover:text-yellow-700 mb-4 sm:mb-8"
        >
          <ArrowLeft className="w-4 h-4 mr-2" />
          Back to Home
        </Link>

        <div className="max-w-2xl mx-auto bg-white rounded-2xl shadow-lg p-4 sm:p-8">
          {renderStep()}

          {/* <div className="flex justify-between mt-6 sm:mt-8">
            {step > 1 && (
              <button
                onClick={() => setStep(step - 1)}
                className="flex items-center text-yellow-600 hover:text-yellow-700 text-sm sm:text-base"
              >
                <ArrowLeft className="w-3 h-3 sm:w-4 sm:h-4 mr-1 sm:mr-2" />
                Previous
              </button>
            )}
              {step < 3 ? (
                <button
                  onClick={async () => {
                    if(step === 1){
                      setIsLoading(true);

                      if(formData.email == ""){
                        alert("Please enter your email");
                        setIsLoading(false);
                        return;
                      }
                      if(formData.id_type == ""){
                        alert("Please enter your id number");
                        setIsLoading(false);
                        return;
                      }
                      if(formData.firstName == ""){
                        alert("Please enter your first name");
                        setIsLoading(false);
                        return;
                      var res = await api.validateEmail(formData.email);
                      console.log(res);
                      if(!res['exists']){
                        // setFormData({ ...formData, email: res.email });
                        setIsLoading(false);
                        setStep(step + 1);
                      }else{
                        alert("Please enter a valid email");
                        setIsLoading(false);
                        return;
                      }
                      
                    }
                    else if (step === 2) {
                      if (formData.userType === "instructor") {
                        setIsLoading(true);
                    
                        if (!formData.institutionName) {
                          alert("Please enter the institution name");
                          setIsLoading(false);
                          return;
                        }
                        if (Number(groupSize) <= 0) {
                          alert("Please enter a valid number of people in the group");
                          setIsLoading(false);
                          return;
                        }
                        
                        alert("Registering group with : " + formData.institutionName + " and " + groupSize + " people");
                        // Register the group first
                        const response = await api.registerGroup({
                          name: formData.institutionName,
                          group_size: Number(groupSize),
                        });
                        try{
                          console.log(response);
                          const id = response.institution.id;
                          setFormData({ ...formData, institutionId: id });
                          if(id){
                            setStep(step + 1);
                          }
                        setIsLoading(false);
                      if (!response) {
                        alert("Failed to register group");
                        return;
                      }
                      }catch(error){
                        console.error("Registration failed:", error);
                        alert(error instanceof Error ? error.message : "Registration failed");
                      }
                      setIsLoading(false);
                    }
                  }

                  // Proceed to the next step
                  // setStep(step + 1);
                }}
                className="ml-auto flex items-center bg-yellow-600 text-white px-4 sm:px-6 py-2 rounded-lg hover:bg-yellow-700"
              >
                <>
                  Next
                  <ArrowRight className="w-3 h-3 sm:w-4 sm:h-4 ml-1 sm:ml-2" />
                </>
              </button>
            ) : null}
          </div> */}
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