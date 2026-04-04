import axios from "axios";
import type {
  AdminStats,
  JobRecord,
  JobRequest,
  PriceEntry,
  RegionInfo,
  TemplateEntry,
} from "./types";

const api = axios.create({
  baseURL: "/api",
  headers: { "Content-Type": "application/json" },
});

// --- Prices ---
export async function fetchPrices(instanceType?: string): Promise<PriceEntry[]> {
  const params = instanceType ? { instance_type: instanceType } : {};
  const { data } = await api.get<{ prices: PriceEntry[] }>("/prices", { params });
  return data.prices;
}

// --- Jobs ---
export async function submitJob(req: JobRequest) {
  const { data } = await api.post<{ status: string; message: string }>("/jobs", req);
  return data;
}

export async function fetchJob(jobId: string): Promise<JobRecord> {
  const { data } = await api.get<JobRecord>(`/jobs/${jobId}`);
  return data;
}

export async function cancelJob(jobId: string) {
  const { data } = await api.delete<{ status: string; job_id: string }>(`/jobs/${jobId}`);
  return data;
}

// --- Templates ---
export async function fetchTemplates(): Promise<TemplateEntry[]> {
  const { data } = await api.get<{ templates: TemplateEntry[] }>("/templates");
  return data.templates;
}

export async function saveTemplate(template: TemplateEntry) {
  const { data } = await api.post<{ status: string; name: string }>("/templates", template);
  return data;
}

export async function deleteTemplate(name: string) {
  const { data } = await api.delete<{ status: string; name: string }>(
    `/templates/${encodeURIComponent(name)}`,
  );
  return data;
}

// --- Upload ---
export async function presignUpload(filename: string, prefix: string = "models") {
  const { data } = await api.post<{ url: string; fields: Record<string, string> }>(
    "/upload/presign",
    { filename, prefix },
  );
  return data;
}

// --- Settings ---
export async function saveWebhookUrl(webhookUrl: string) {
  const { data } = await api.put<{ status: string }>("/settings/webhook", {
    webhook_url: webhookUrl,
  });
  return data;
}

// --- Admin ---
export async function fetchAdminJobs(): Promise<JobRecord[]> {
  const { data } = await api.get<{ jobs: JobRecord[]; count: number }>("/admin/jobs");
  return data.jobs;
}

export async function adminForceCancel(jobId: string) {
  const { data } = await api.delete<{ status: string }>(`/admin/jobs/${jobId}`);
  return data;
}

export async function adminForceRetry(jobId: string) {
  const { data } = await api.post<{ status: string }>(`/admin/jobs/${jobId}/retry`);
  return data;
}

export async function fetchAdminRegions(): Promise<RegionInfo[]> {
  const { data } = await api.get<{ regions: RegionInfo[] }>("/admin/regions");
  return data.regions;
}

export async function updateRegionCapacity(region: string, capacity: number) {
  const { data } = await api.put<{ region: string; capacity: number }>(
    `/admin/regions/${region}/capacity`,
    { capacity },
  );
  return data;
}

export async function fetchAdminStats(): Promise<AdminStats> {
  const { data } = await api.get<AdminStats>("/admin/stats");
  return data;
}
