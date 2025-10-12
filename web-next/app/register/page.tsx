"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";

export default function RegisterRedirectPage() {
  const router = useRouter();

  useEffect(() => {
    // Redirect to home page since event_id is required
    router.push("/");
  }, [router]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="text-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-gray-900 mx-auto"></div>
        <p className="mt-4 text-gray-600">Redirecting...</p>
      </div>
    </div>
  );
}
