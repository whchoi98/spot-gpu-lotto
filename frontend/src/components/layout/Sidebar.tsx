import { Link, useLocation } from "react-router-dom";
import {
  LayoutDashboard,
  Cpu,
  DollarSign,
  FileText,
  Settings,
  ShieldCheck,
  Plus,
} from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { cn } from "@/lib/utils";

const userLinks = [
  { to: "/", label: "Dashboard", icon: LayoutDashboard },
  { to: "/jobs", label: "Jobs", icon: Cpu },
  { to: "/jobs/new", label: "New Job", icon: Plus },
  { to: "/prices", label: "Prices", icon: DollarSign },
  { to: "/templates", label: "Templates", icon: FileText },
  { to: "/settings", label: "Settings", icon: Settings },
];

const adminLinks = [
  { to: "/admin", label: "Admin Dashboard", icon: ShieldCheck },
  { to: "/admin/jobs", label: "All Jobs", icon: Cpu },
  { to: "/admin/regions", label: "Regions", icon: LayoutDashboard },
];

export function Sidebar() {
  const location = useLocation();
  const user = useAuth();

  return (
    <aside className="flex h-screen w-56 flex-col border-r bg-card px-3 py-4">
      <div className="mb-6 px-2 text-lg font-bold">GPU Spot Lotto</div>

      <nav className="flex flex-1 flex-col gap-1">
        {userLinks.map(({ to, label, icon: Icon }) => (
          <Link
            key={to}
            to={to}
            className={cn(
              "flex items-center gap-2 rounded-md px-2 py-1.5 text-sm hover:bg-accent",
              location.pathname === to && "bg-accent font-medium",
            )}
          >
            <Icon className="h-4 w-4" />
            {label}
          </Link>
        ))}

        {user.role === "admin" && (
          <>
            <div className="my-3 border-t" />
            <div className="px-2 text-xs font-semibold uppercase text-muted-foreground">
              Admin
            </div>
            {adminLinks.map(({ to, label, icon: Icon }) => (
              <Link
                key={to}
                to={to}
                className={cn(
                  "flex items-center gap-2 rounded-md px-2 py-1.5 text-sm hover:bg-accent",
                  location.pathname === to && "bg-accent font-medium",
                )}
              >
                <Icon className="h-4 w-4" />
                {label}
              </Link>
            ))}
          </>
        )}
      </nav>
    </aside>
  );
}
