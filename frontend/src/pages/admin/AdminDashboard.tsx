import { useAdminStats, useAdminRegions } from "@/hooks/useAdmin";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export default function AdminDashboard() {
  const { data: stats } = useAdminStats();
  const { data: regions } = useAdminRegions();

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Admin Dashboard</h1>

      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Active Jobs
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{stats?.active_jobs ?? "—"}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Queue Depth
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{stats?.queue_depth ?? "—"}</div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Region Capacity</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-3">
            {(regions ?? []).map((r) => (
              <div key={r.region} className="rounded-md border p-4">
                <div className="text-sm font-medium">{r.region}</div>
                <div className="mt-1 text-2xl font-bold">{r.available_capacity}</div>
                <div className="text-xs text-muted-foreground">GPU slots available</div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
