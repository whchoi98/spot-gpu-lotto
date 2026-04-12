import { useState, useMemo } from "react";
import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import { Input } from "@/components/ui/input";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import { JobStatusBadge } from "./JobStatusBadge";
import { ArrowUpDown, ArrowUp, ArrowDown, Search } from "lucide-react";
import type { JobRecord } from "@/lib/types";

interface JobTableProps {
  jobs: JobRecord[];
}

type SortKey = "job_id" | "status" | "instance_type" | "region" | "created_at" | "duration";
type SortDir = "asc" | "desc";

function formatTime(epoch: number): string {
  return new Date(epoch * 1000).toLocaleString();
}

function getDurationSec(start: number, end?: number): number {
  return (end ?? Math.floor(Date.now() / 1000)) - start;
}

function formatDuration(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  const min = Math.floor(seconds / 60);
  const sec = seconds % 60;
  return `${min}m ${sec}s`;
}

const STATUS_OPTIONS: Array<{ value: string; label_en: string; label_ko: string }> = [
  { value: "all", label_en: "All Status", label_ko: "전체 상태" },
  { value: "queued", label_en: "Queued", label_ko: "대기중" },
  { value: "running", label_en: "Running", label_ko: "실행중" },
  { value: "succeeded", label_en: "Succeeded", label_ko: "성공" },
  { value: "failed", label_en: "Failed", label_ko: "실패" },
  { value: "cancelling", label_en: "Cancelling", label_ko: "취소중" },
  { value: "cancelled", label_en: "Cancelled", label_ko: "취소됨" },
];

function SortIcon({ column, sortKey, sortDir }: { column: SortKey; sortKey: SortKey; sortDir: SortDir }) {
  if (column !== sortKey) return <ArrowUpDown className="ml-1 inline h-3 w-3 opacity-30" />;
  return sortDir === "asc"
    ? <ArrowUp className="ml-1 inline h-3 w-3" />
    : <ArrowDown className="ml-1 inline h-3 w-3" />;
}

export function JobTable({ jobs }: JobTableProps) {
  const { i18n } = useTranslation();
  const isKo = i18n.language === "ko";

  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [sortKey, setSortKey] = useState<SortKey>("created_at");
  const [sortDir, setSortDir] = useState<SortDir>("desc");

  const handleSort = (key: SortKey) => {
    if (sortKey === key) {
      setSortDir(prev => prev === "asc" ? "desc" : "asc");
    } else {
      setSortKey(key);
      setSortDir(key === "created_at" ? "desc" : "asc");
    }
  };

  const filtered = useMemo(() => {
    let result = jobs;

    // Status filter
    if (statusFilter !== "all") {
      result = result.filter(j => j.status === statusFilter);
    }

    // Search filter
    if (search.trim()) {
      const q = search.trim().toLowerCase();
      result = result.filter(j =>
        j.job_id.toLowerCase().includes(q) ||
        j.region.toLowerCase().includes(q) ||
        j.instance_type.toLowerCase().includes(q) ||
        j.status.toLowerCase().includes(q)
      );
    }

    // Sort
    const sorted = [...result].sort((a, b) => {
      let cmp = 0;
      switch (sortKey) {
        case "job_id":
          cmp = a.job_id.localeCompare(b.job_id);
          break;
        case "status":
          cmp = a.status.localeCompare(b.status);
          break;
        case "instance_type":
          cmp = a.instance_type.localeCompare(b.instance_type);
          break;
        case "region":
          cmp = a.region.localeCompare(b.region);
          break;
        case "created_at":
          cmp = a.created_at - b.created_at;
          break;
        case "duration":
          cmp = getDurationSec(a.created_at, a.finished_at ?? undefined)
              - getDurationSec(b.created_at, b.finished_at ?? undefined);
          break;
      }
      return sortDir === "asc" ? cmp : -cmp;
    });

    return sorted;
  }, [jobs, search, statusFilter, sortKey, sortDir]);

  const thClass = "cursor-pointer select-none hover:text-foreground transition-colors";

  return (
    <div className="space-y-3">
      {/* Search & Filter Bar */}
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder={isKo ? "Job ID, 리전, 인스턴스로 검색..." : "Search by Job ID, region, instance..."}
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="pl-9"
          />
        </div>
        <Select value={statusFilter} onValueChange={setStatusFilter}>
          <SelectTrigger className="w-full sm:w-[160px]">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {STATUS_OPTIONS.map(opt => (
              <SelectItem key={opt.value} value={opt.value}>
                {isKo ? opt.label_ko : opt.label_en}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {/* Result count */}
      {(search || statusFilter !== "all") && (
        <p className="text-sm text-muted-foreground">
          {isKo
            ? `${filtered.length}건 / 전체 ${jobs.length}건`
            : `${filtered.length} of ${jobs.length} jobs`}
        </p>
      )}

      {/* Table */}
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className={thClass} onClick={() => handleSort("job_id")}>
              Job ID <SortIcon column="job_id" sortKey={sortKey} sortDir={sortDir} />
            </TableHead>
            <TableHead className={thClass} onClick={() => handleSort("status")}>
              Status <SortIcon column="status" sortKey={sortKey} sortDir={sortDir} />
            </TableHead>
            <TableHead className={thClass} onClick={() => handleSort("instance_type")}>
              Instance <SortIcon column="instance_type" sortKey={sortKey} sortDir={sortDir} />
            </TableHead>
            <TableHead className={thClass} onClick={() => handleSort("region")}>
              Region <SortIcon column="region" sortKey={sortKey} sortDir={sortDir} />
            </TableHead>
            <TableHead className={thClass} onClick={() => handleSort("duration")}>
              Duration <SortIcon column="duration" sortKey={sortKey} sortDir={sortDir} />
            </TableHead>
            <TableHead className={thClass} onClick={() => handleSort("created_at")}>
              Created <SortIcon column="created_at" sortKey={sortKey} sortDir={sortDir} />
            </TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {filtered.map((job) => (
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
                {formatDuration(getDurationSec(job.created_at, job.finished_at ?? undefined))}
              </TableCell>
              <TableCell className="text-sm text-muted-foreground">
                {formatTime(job.created_at)}
              </TableCell>
            </TableRow>
          ))}
          {filtered.length === 0 && (
            <TableRow>
              <TableCell colSpan={6} className="text-center text-muted-foreground">
                {search || statusFilter !== "all"
                  ? (isKo ? "검색 결과가 없습니다" : "No matching jobs")
                  : (isKo ? "작업 기록이 없습니다" : "No jobs found")}
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </div>
  );
}
