import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { useTranslation } from "react-i18next";
import { fetchAdminStats, fetchPrices, fetchAdminJobs } from "@/lib/api";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { PriceTable } from "@/components/prices/PriceTable";
import { JobStatusBadge } from "@/components/jobs/JobStatusBadge";
import { Skeleton } from "@/components/ui/skeleton";
import { Plus, Cpu, Layers, DollarSign } from "lucide-react";

export default function Dashboard() {
  const { t } = useTranslation();
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
        <h1 className="text-2xl font-bold">{t("dash_title")}</h1>
        <Button asChild>
          <Link to="/jobs/new">
            <Plus className="mr-2 h-4 w-4" />
            {t("dash_new_job")}
          </Link>
        </Button>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <Card className="relative overflow-hidden">
          <div className="absolute inset-x-0 top-0 h-1 bg-gradient-to-r from-blue-500 to-cyan-400" />
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              {t("dash_active_jobs")}
            </CardTitle>
            <Cpu className="h-4 w-4 text-blue-500" />
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{stats?.active_jobs ?? "\u2014"}</div>
          </CardContent>
        </Card>
        <Card className="relative overflow-hidden">
          <div className="absolute inset-x-0 top-0 h-1 bg-gradient-to-r from-violet-500 to-purple-400" />
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              {t("dash_queue_depth")}
            </CardTitle>
            <Layers className="h-4 w-4 text-violet-500" />
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{stats?.queue_depth ?? "\u2014"}</div>
          </CardContent>
        </Card>
        <Card className="relative overflow-hidden">
          <div className="absolute inset-x-0 top-0 h-1 bg-gradient-to-r from-emerald-500 to-green-400" />
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              {t("dash_cheapest")}
            </CardTitle>
            <DollarSign className="h-4 w-4 text-emerald-500" />
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">
              {prices && prices.length > 0
                ? `$${Math.min(...prices.map((p) => p.price)).toFixed(3)}${t("dash_per_hr")}`
                : "\u2014"}
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>{t("dash_recent_jobs")}</CardTitle>
          </CardHeader>
          <CardContent>
            {recentJobs.length === 0 ? (
              <p className="text-sm text-muted-foreground">{t("dash_no_jobs")}</p>
            ) : (
              <div className="space-y-2">
                {recentJobs.map((job) => (
                  <Link
                    key={job.job_id}
                    to={`/jobs/${job.job_id}`}
                    className="flex items-center justify-between rounded-md px-2 py-1.5 transition-colors hover:bg-accent"
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
            <CardTitle>{t("dash_spot_prices")}</CardTitle>
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
