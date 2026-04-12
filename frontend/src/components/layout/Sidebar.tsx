import { Link, useLocation } from "react-router-dom";
import {
  LayoutDashboard,
  Cpu,
  DollarSign,
  FileText,
  Settings,
  ShieldCheck,
  Plus,
  BookOpen,
  BarChart3,
  Globe,
} from "lucide-react";
import { useTranslation } from "react-i18next";
import { useAuth } from "@/hooks/useAuth";
import { cn } from "@/lib/utils";

export function Sidebar() {
  const location = useLocation();
  const user = useAuth();
  const { t } = useTranslation();

  const userLinks = [
    { to: "/", label: t("nav_dashboard"), icon: LayoutDashboard },
    { to: "/jobs", label: t("nav_jobs"), icon: Cpu },
    { to: "/jobs/new", label: t("nav_new_job"), icon: Plus },
    { to: "/prices", label: t("nav_prices"), icon: DollarSign },
    { to: "/templates", label: t("nav_templates"), icon: FileText },
    { to: "/guide", label: t("nav_guide"), icon: BookOpen },
    { to: "/settings", label: t("nav_settings"), icon: Settings },
  ];

  const adminLinks = [
    { to: "/admin", label: t("nav_admin_dashboard"), icon: ShieldCheck },
    { to: "/admin/jobs", label: t("nav_admin_jobs"), icon: Cpu },
    { to: "/admin/regions", label: t("nav_admin_regions"), icon: Globe },
  ];

  const isActive = (to: string) => {
    if (to === "/") return location.pathname === "/";
    // Exact match, or sub-path match only when the next char is "/"
    return location.pathname === to || location.pathname.startsWith(to + "/");
  };

  return (
    <aside className="flex h-screen w-60 flex-col border-r bg-[hsl(var(--sidebar))] px-3 py-4">
      <div className="mb-8 flex items-center gap-2.5 px-3">
        <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-blue-500 to-violet-600 text-sm font-bold text-white">
          G
        </div>
        <div>
          <div className="text-sm font-bold text-[hsl(var(--sidebar-foreground))]">
            GPU Spot Lotto
          </div>
          <div className="text-[10px] text-muted-foreground">Multi-Region GPU Orchestrator</div>
        </div>
      </div>

      <nav className="flex flex-1 flex-col gap-0.5">
        {userLinks.map(({ to, label, icon: Icon }) => (
          <Link
            key={to}
            to={to}
            className={cn(
              "group flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm transition-colors",
              "text-[hsl(var(--sidebar-foreground))]/70 hover:bg-accent hover:text-[hsl(var(--sidebar-foreground))]",
              isActive(to) &&
                "bg-accent font-medium text-[hsl(var(--sidebar-accent))] shadow-sm",
            )}
          >
            <Icon
              className={cn(
                "h-4 w-4 shrink-0 transition-colors",
                isActive(to)
                  ? "text-[hsl(var(--sidebar-accent))]"
                  : "text-muted-foreground group-hover:text-[hsl(var(--sidebar-foreground))]",
              )}
            />
            {label}
          </Link>
        ))}

        <a
          href="/grafana/d/gpu-spot-lotto/gpu-spot-lotto"
          target="_blank"
          rel="noopener noreferrer"
          className="group flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm text-[hsl(var(--sidebar-foreground))]/70 transition-colors hover:bg-accent hover:text-[hsl(var(--sidebar-foreground))]"
        >
          <BarChart3 className="h-4 w-4 shrink-0 text-muted-foreground group-hover:text-[hsl(var(--sidebar-foreground))] transition-colors" />
          {t("nav_monitoring")}
          <span className="ml-auto text-[10px] text-muted-foreground">Grafana</span>
        </a>

        {user.role === "admin" && (
          <>
            <div className="my-3 border-t border-border/50" />
            <div className="mb-1 px-3 text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
              {t("nav_admin")}
            </div>
            {adminLinks.map(({ to, label, icon: Icon }) => (
              <Link
                key={to}
                to={to}
                className={cn(
                  "group flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm transition-colors",
                  "text-[hsl(var(--sidebar-foreground))]/70 hover:bg-accent hover:text-[hsl(var(--sidebar-foreground))]",
                  isActive(to) &&
                    "bg-accent font-medium text-[hsl(var(--sidebar-accent))] shadow-sm",
                )}
              >
                <Icon
                  className={cn(
                    "h-4 w-4 shrink-0 transition-colors",
                    isActive(to)
                      ? "text-[hsl(var(--sidebar-accent))]"
                      : "text-muted-foreground group-hover:text-[hsl(var(--sidebar-foreground))]",
                  )}
                />
                {label}
              </Link>
            ))}
          </>
        )}
      </nav>

      <div className="mt-auto border-t border-border/50 pt-3">
        <div className="flex items-center gap-2 px-3 py-1">
          <div className="flex h-7 w-7 items-center justify-center rounded-full bg-gradient-to-br from-emerald-500 to-teal-600 text-xs font-medium text-white">
            {(user.user_id ?? "?").charAt(0).toUpperCase()}
          </div>
          <div className="flex-1 overflow-hidden">
            <div className="truncate text-xs font-medium text-[hsl(var(--sidebar-foreground))]">
              {user.user_id ?? "anonymous"}
            </div>
            <div className="text-[10px] text-muted-foreground">{user.role}</div>
          </div>
        </div>
      </div>
    </aside>
  );
}
