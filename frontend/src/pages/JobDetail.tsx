import { useParams, useNavigate } from "react-router-dom";
import { useJob, useCancelJob } from "@/hooks/useJobs";
import { useJobStream } from "@/hooks/useJobStream";
import { JobStatusBadge } from "@/components/jobs/JobStatusBadge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import type { JobStatus } from "@/lib/types";

function formatTime(epoch: number): string {
  return new Date(epoch * 1000).toLocaleString();
}

export default function JobDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { data: job, isLoading } = useJob(id!);
  const { events, connected } = useJobStream(id!);
  const cancelMut = useCancelJob();

  const currentStatus: JobStatus | undefined =
    events.length > 0 ? events[events.length - 1]!.status : job?.status;

  if (isLoading) {
    return <div className="space-y-4"><Skeleton className="h-8 w-48" /><Skeleton className="h-64 w-full" /></div>;
  }
  if (!job) {
    return <div className="text-muted-foreground">Job not found.</div>;
  }

  const canCancel = currentStatus === "running" || currentStatus === "queued";

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <h1 className="text-2xl font-bold font-mono">{job.job_id.slice(0, 12)}</h1>
          {currentStatus && <JobStatusBadge status={currentStatus} />}
          {connected && <Badge variant="outline" className="text-green-600">SSE Live</Badge>}
        </div>
        <div className="flex gap-2">
          {canCancel && (
            <Button variant="destructive" size="sm" onClick={() => cancelMut.mutate(job.job_id)} disabled={cancelMut.isPending}>Cancel Job</Button>
          )}
          <Button variant="outline" size="sm" onClick={() => navigate("/jobs")}>Back to Jobs</Button>
        </div>
      </div>
      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader><CardTitle>Job Info</CardTitle></CardHeader>
          <CardContent className="space-y-2 text-sm">
            <Row label="Job ID" value={job.job_id} mono />
            <Row label="User" value={job.user_id} />
            <Row label="Instance" value={job.instance_type} mono />
            <Row label="Region" value={job.region} />
            <Row label="Pod" value={job.pod_name} mono />
            <Row label="Checkpoint" value={job.checkpoint_enabled ? "Enabled" : "Disabled"} />
            <Row label="Retries" value={String(job.retry_count)} />
            <Row label="Created" value={formatTime(job.created_at)} />
            {job.finished_at && <Row label="Finished" value={formatTime(job.finished_at)} />}
            {job.error_reason && <Row label="Error" value={job.error_reason} />}
          </CardContent>
        </Card>
        <Card>
          <CardHeader><CardTitle>Status Events</CardTitle></CardHeader>
          <CardContent>
            {events.length === 0 ? (
              <p className="text-sm text-muted-foreground">
                {connected ? "Waiting for events..." : "No events received."}
              </p>
            ) : (
              <div className="space-y-2">
                {events.map((evt, i) => (
                  <div key={i} className="flex items-center gap-2">
                    <JobStatusBadge status={evt.status} />
                    <span className="text-xs text-muted-foreground">{JSON.stringify(evt)}</span>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function Row({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <>
      <div className="flex justify-between">
        <span className="text-muted-foreground">{label}</span>
        <span className={mono ? "font-mono" : ""}>{value}</span>
      </div>
      <Separator />
    </>
  );
}
