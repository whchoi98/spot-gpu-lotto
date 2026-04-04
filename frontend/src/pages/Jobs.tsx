import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { fetchAdminJobs } from "@/lib/api";
import { JobTable } from "@/components/jobs/JobTable";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Plus } from "lucide-react";

export default function Jobs() {
  const { data: jobs, isLoading } = useQuery({
    queryKey: ["admin-jobs"],
    queryFn: fetchAdminJobs,
    refetchInterval: 10_000,
  });

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">My Jobs</h1>
        <Button asChild>
          <Link to="/jobs/new">
            <Plus className="mr-2 h-4 w-4" />
            New Job
          </Link>
        </Button>
      </div>
      <Card>
        <CardHeader><CardTitle>Job History</CardTitle></CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="space-y-2">
              {Array.from({ length: 5 }).map((_, i) => (
                <Skeleton key={i} className="h-12 w-full" />
              ))}
            </div>
          ) : (
            <JobTable jobs={jobs ?? []} />
          )}
        </CardContent>
      </Card>
    </div>
  );
}
