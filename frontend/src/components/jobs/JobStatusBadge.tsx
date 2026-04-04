import { Badge } from "@/components/ui/badge";
import type { JobStatus } from "@/lib/types";

const statusConfig: Record<JobStatus, { label: string; variant: "default" | "secondary" | "destructive" | "outline" }> = {
  queued: { label: "Queued", variant: "secondary" },
  running: { label: "Running", variant: "default" },
  succeeded: { label: "Succeeded", variant: "outline" },
  failed: { label: "Failed", variant: "destructive" },
  cancelling: { label: "Cancelling", variant: "secondary" },
  cancelled: { label: "Cancelled", variant: "secondary" },
};

export function JobStatusBadge({ status }: { status: JobStatus }) {
  const config = statusConfig[status];
  return <Badge variant={config.variant}>{config.label}</Badge>;
}
