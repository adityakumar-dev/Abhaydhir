import { UserProvider } from "@/context/admin_context";

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <UserProvider>
      {children}
    </UserProvider>
  );
}
