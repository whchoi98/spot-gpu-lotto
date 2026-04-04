import { Routes, Route } from "react-router-dom";
import { AuthContext } from "@/hooks/useAuth";
import { getUserFromToken } from "@/lib/auth";
import { AppLayout } from "@/components/layout/AppLayout";
import Prices from "@/pages/Prices";
import Jobs from "@/pages/Jobs";
import JobNew from "@/pages/JobNew";
import JobDetail from "@/pages/JobDetail";
import Templates from "@/pages/Templates";
import Dashboard from "@/pages/Dashboard";
import Settings from "@/pages/Settings";
import AdminDashboard from "@/pages/admin/AdminDashboard";
import AdminJobs from "@/pages/admin/AdminJobs";
import AdminRegions from "@/pages/admin/AdminRegions";

const user = getUserFromToken();

export default function App() {
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
          <Route path="/settings" element={<Settings />} />
          <Route path="/admin" element={<AdminDashboard />} />
          <Route path="/admin/jobs" element={<AdminJobs />} />
          <Route path="/admin/regions" element={<AdminRegions />} />
        </Route>
      </Routes>
    </AuthContext.Provider>
  );
}
