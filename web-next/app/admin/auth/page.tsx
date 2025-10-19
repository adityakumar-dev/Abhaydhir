"use client";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { adminLogin, adminRegister } from "@/services/adminAuth";

export default function AdminAuthPage() {
  const router = useRouter();
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [adminKey, setAdminKey] = useState("");
  const [name,setName] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      if (mode === "login") {
        await adminLogin(email, password);
        router.replace("/admin/dashboard");
      } else {
        await adminRegister({ email, password, name: name, adminKey });
        setMode('login');
      }
    } catch (err: any) {
      setError(err.message || "Authentication failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="w-full max-w-md bg-white rounded-xl shadow-lg p-8">
        <h2 className="text-2xl font-bold mb-6 text-center">
          {mode === "login" ? "Admin Login" : "Admin Register"}
        </h2>
        <form className="space-y-4" onSubmit={handleSubmit}>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
            <input
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-yellow-200 focus:border-yellow-400"
              required
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
            <input
              type="password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-yellow-200 focus:border-yellow-400"
              required
            />
          </div>
          {mode === "register" && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Admin Key</label>
              <input
                type="text"
                value={adminKey}
                onChange={e => setAdminKey(e.target.value)}
                className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-yellow-200 focus:border-yellow-400"
                required
              />
              <label className="block text-sm font-medium text-gray-700 mb-1">Your Name</label>
              <input
                type="text"
                value={name}
                onChange={e => setName(e.target.value)}
                className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-yellow-200 focus:border-yellow-400"
                required
              />
            </div>
          )}
          {error && <div className="text-red-600 text-sm text-center">{error}</div>}
          <button
            type="submit"
            className="w-full bg-yellow-600 text-white py-2 rounded-lg hover:bg-yellow-700 transition-colors disabled:bg-yellow-400"
            disabled={loading}
          >
            {loading ? "Processing..." : mode === "login" ? "Login" : "Register"}
          </button>
        </form>
        <div className="mt-6 text-center">
          <button
            type="button"
            className="text-yellow-600 hover:underline"
            onClick={() => setMode(mode === "login" ? "register" : "login")}
          >
            {mode === "login" ? "Don't have an account? Register" : "Already have an account? Login"}
          </button>
        </div>
      </div>
    </div>
  );
}
