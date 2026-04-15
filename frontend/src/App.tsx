import { useState, useEffect } from "react";
import { Routes, Route } from "react-router-dom";
import { AuthContext } from "@/hooks/useAuth";
import { fetchMe } from "@/lib/api";
import { AppLayout } from "@/components/layout/AppLayout";
import Prices from "@/pages/Prices";
import Jobs from "@/pages/Jobs";
import JobNew from "@/pages/JobNew";
import JobDetail from "@/pages/JobDetail";
import Templates from "@/pages/Templates";
import Dashboard from "@/pages/Dashboard";
import Settings from "@/pages/Settings";
import Guide from "@/pages/Guide";
import Agent from "@/pages/Agent";
import AdminDashboard from "@/pages/admin/AdminDashboard";
import AdminJobs from "@/pages/admin/AdminJobs";
import AdminRegions from "@/pages/admin/AdminRegions";
import type { UserInfo } from "@/lib/types";

export default function App() {
  const [user, setUser] = useState<UserInfo | null>(null);

  useEffect(() => {
    fetchMe()
      .then(setUser)
      .catch(() => setUser({ user_id: "anonymous", role: "user" }));
  }, []);

  if (!user) return null;

  return (
    <AuthContext.Provider value={user}>
      <Routes>
        <Route element={<AppLayout />}>
          <Route path="/" element={<Dashboard />} />
          <Route path="/jobs" element={<Jobs />} />
          <Route path="/jobs/new" element={<JobNew />} />
          <Route path="/jobs/:id" element={<JobDetail />} />
          <Route path="/prices" element={<Prices />} />
          <Route path="/templates" element={<Templates />} />
          <Route path="/agent" element={<Agent />} />
          <Route path="/guide" element={<Guide />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="/admin" element={<AdminDashboard />} />
          <Route path="/admin/jobs" element={<AdminJobs />} />
          <Route path="/admin/regions" element={<AdminRegions />} />
        </Route>
      </Routes>
    </AuthContext.Provider>
  );
}
