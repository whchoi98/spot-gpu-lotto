import { useAdminJobs, useForceCancel, useForceRetry } from "@/hooks/useAdmin";
import { JobStatusBadge } from "@/components/jobs/JobStatusBadge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Skeleton } from "@/components/ui/skeleton";
import type { JobRecord } from "@/lib/types";

export default function AdminJobs() {
  const { data: jobs, isLoading } = useAdminJobs();
  const cancelMut = useForceCancel();
  const retryMut = useForceRetry();

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">All Jobs (Admin)</h1>

      <Card>
        <CardHeader>
          <CardTitle>Active Jobs</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="space-y-2">
              {Array.from({ length: 5 }).map((_, i) => (
                <Skeleton key={i} className="h-12 w-full" />
              ))}
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Job ID</TableHead>
                  <TableHead>User</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Instance</TableHead>
                  <TableHead>Region</TableHead>
                  <TableHead>Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {(jobs ?? []).map((job: JobRecord) => (
                  <TableRow key={job.job_id}>
                    <TableCell className="font-mono text-sm">{job.job_id.slice(0, 8)}</TableCell>
                    <TableCell>{job.user_id}</TableCell>
                    <TableCell>
                      <JobStatusBadge status={job.status} />
                    </TableCell>
                    <TableCell className="font-mono text-sm">{job.instance_type}</TableCell>
                    <TableCell>{job.region}</TableCell>
                    <TableCell>
                      <div className="flex gap-1">
                        {(job.status === "running" || job.status === "queued") && (
                          <Button
                            variant="destructive"
                            size="sm"
                            onClick={() => cancelMut.mutate(job.job_id)}
                            disabled={cancelMut.isPending}
                          >
                            Cancel
                          </Button>
                        )}
                        {job.status === "failed" && (
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => retryMut.mutate(job.job_id)}
                            disabled={retryMut.isPending}
                          >
                            Retry
                          </Button>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
                {(jobs ?? []).length === 0 && (
                  <TableRow>
                    <TableCell colSpan={6} className="text-center text-muted-foreground">
                      No active jobs
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
