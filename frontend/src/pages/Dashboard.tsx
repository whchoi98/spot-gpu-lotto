import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { fetchAdminStats, fetchPrices, fetchAdminJobs } from "@/lib/api";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { PriceTable } from "@/components/prices/PriceTable";
import { JobStatusBadge } from "@/components/jobs/JobStatusBadge";
import { Skeleton } from "@/components/ui/skeleton";
import { Plus } from "lucide-react";

export default function Dashboard() {
  const { data: stats } = useQuery({
    queryKey: ["admin-stats"],
    queryFn: fetchAdminStats,
    refetchInterval: 10_000,
  });
  const { data: prices, isLoading: pricesLoading } = useQuery({
    queryKey: ["prices"],
    queryFn: () => fetchPrices(),
    refetchInterval: 30_000,
  });
  const { data: jobs } = useQuery({
    queryKey: ["admin-jobs"],
    queryFn: fetchAdminJobs,
    refetchInterval: 10_000,
  });

  const recentJobs = (jobs ?? []).slice(0, 5);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Dashboard</h1>
        <Button asChild>
          <Link to="/jobs/new">
            <Plus className="mr-2 h-4 w-4" />
            New Job
          </Link>
        </Button>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Active Jobs</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{stats?.active_jobs ?? "—"}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Queue Depth</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{stats?.queue_depth ?? "—"}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Cheapest Spot</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">
              {prices && prices.length > 0
                ? `$${Math.min(...prices.map((p) => p.price)).toFixed(3)}/hr`
                : "—"}
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Recent Jobs</CardTitle>
          </CardHeader>
          <CardContent>
            {recentJobs.length === 0 ? (
              <p className="text-sm text-muted-foreground">No jobs yet</p>
            ) : (
              <div className="space-y-2">
                {recentJobs.map((job) => (
                  <Link
                    key={job.job_id}
                    to={`/jobs/${job.job_id}`}
                    className="flex items-center justify-between rounded-md px-2 py-1.5 hover:bg-accent"
                  >
                    <span className="font-mono text-sm">{job.job_id.slice(0, 8)}</span>
                    <div className="flex items-center gap-2">
                      <span className="text-sm text-muted-foreground">{job.instance_type}</span>
                      <JobStatusBadge status={job.status} />
                    </div>
                  </Link>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Spot Prices</CardTitle>
          </CardHeader>
          <CardContent>
            {pricesLoading ? (
              <Skeleton className="h-40 w-full" />
            ) : (
              <PriceTable prices={prices ?? []} />
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
