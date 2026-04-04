import { Link } from "react-router-dom";
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import { JobStatusBadge } from "./JobStatusBadge";
import type { JobRecord } from "@/lib/types";

interface JobTableProps {
  jobs: JobRecord[];
}

function formatTime(epoch: number): string {
  return new Date(epoch * 1000).toLocaleString();
}

function duration(start: number, end?: number): string {
  const seconds = (end ?? Math.floor(Date.now() / 1000)) - start;
  if (seconds < 60) return `${seconds}s`;
  const min = Math.floor(seconds / 60);
  const sec = seconds % 60;
  return `${min}m ${sec}s`;
}

export function JobTable({ jobs }: JobTableProps) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Job ID</TableHead>
          <TableHead>Status</TableHead>
          <TableHead>Instance</TableHead>
          <TableHead>Region</TableHead>
          <TableHead>Duration</TableHead>
          <TableHead>Created</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {jobs.map((job) => (
          <TableRow key={job.job_id}>
            <TableCell>
              <Link to={`/jobs/${job.job_id}`}
                className="font-mono text-sm text-primary underline-offset-4 hover:underline">
                {job.job_id.slice(0, 8)}
              </Link>
            </TableCell>
            <TableCell><JobStatusBadge status={job.status} /></TableCell>
            <TableCell className="font-mono text-sm">{job.instance_type}</TableCell>
            <TableCell>{job.region}</TableCell>
            <TableCell className="font-mono text-sm">
              {duration(job.created_at, job.finished_at ?? undefined)}
            </TableCell>
            <TableCell className="text-sm text-muted-foreground">
              {formatTime(job.created_at)}
            </TableCell>
          </TableRow>
        ))}
        {jobs.length === 0 && (
          <TableRow>
            <TableCell colSpan={6} className="text-center text-muted-foreground">
              No jobs found
            </TableCell>
          </TableRow>
        )}
      </TableBody>
    </Table>
  );
}
