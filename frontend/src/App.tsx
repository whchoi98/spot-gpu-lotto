import { Routes, Route } from "react-router-dom";
import { AuthContext } from "@/hooks/useAuth";
import { getUserFromToken } from "@/lib/auth";
import { AppLayout } from "@/components/layout/AppLayout";
import Prices from "@/pages/Prices";
import Jobs from "@/pages/Jobs";

function Placeholder({ name }: { name: string }) {
  return <div className="text-lg text-muted-foreground">{name} — coming soon</div>;
}

const user = getUserFromToken();

export default function App() {
  return (
    <AuthContext.Provider value={user}>
      <Routes>
        <Route element={<AppLayout />}>
          <Route path="/" element={<Placeholder name="Dashboard" />} />
          <Route path="/jobs" element={<Jobs />} />
          <Route path="/jobs/new" element={<Placeholder name="New Job" />} />
          <Route path="/jobs/:id" element={<Placeholder name="Job Detail" />} />
          <Route path="/prices" element={<Prices />} />
          <Route path="/templates" element={<Placeholder name="Templates" />} />
          <Route path="/settings" element={<Placeholder name="Settings" />} />
          <Route path="/admin" element={<Placeholder name="Admin Dashboard" />} />
          <Route path="/admin/jobs" element={<Placeholder name="Admin Jobs" />} />
          <Route path="/admin/regions" element={<Placeholder name="Admin Regions" />} />
        </Route>
      </Routes>
    </AuthContext.Provider>
  );
}
