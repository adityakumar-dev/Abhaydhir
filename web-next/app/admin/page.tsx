"use client";
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useUser } from "@/context/admin_context";

export default function AdminPage() {
  const router = useRouter();
  const { user, loading } = useUser();

  useEffect(() => {
    if (loading) return;
    if (user) {
      router.replace("/admin/dashboard");
    } else {
      router.replace("/admin/auth");
    }
  }, [user, loading, router]);

  return null;
}
