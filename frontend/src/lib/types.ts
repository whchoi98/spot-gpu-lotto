export type JobStatus =
  | "queued"
  | "running"
  | "succeeded"
  | "failed"
  | "cancelling"
  | "cancelled";

export interface JobRequest {
  image: string;
  command: string[];
  instance_type: string;
  gpu_type: string;
  gpu_count: number;
  storage_mode: string;
  checkpoint_enabled: boolean;
  webhook_url?: string;
}

export interface JobRecord {
  job_id: string;
  user_id: string;
  region: string;
  status: JobStatus;
  pod_name: string;
  instance_type: string;
  created_at: number;
  finished_at?: number;
  retry_count: number;
  checkpoint_enabled: boolean;
  webhook_url?: string;
  result_path?: string;
  error_reason?: string;
}

export interface PriceEntry {
  region: string;
  instance_type: string;
  price: number;
}

export interface TemplateEntry {
  name: string;
  image: string;
  instance_type: string;
  gpu_count: number;
  gpu_type: string;
  storage_mode: string;
  checkpoint_enabled: boolean;
  command: string[];
}

export interface RegionInfo {
  region: string;
  available_capacity: number;
}

export interface AdminStats {
  active_jobs: number;
  queue_depth: number;
}

export interface UserInfo {
  user_id: string;
  role: "admin" | "user";
}

// Agent chat types
export interface AgentChatMessage {
  role: "user" | "assistant";
  content: string;
  model?: string;
  actions?: ProposedAction[];
}

export interface ProposedAction {
  action: string;
  instance_type?: string;
  image?: string;
  command?: string;
  gpu_count?: number;
  region?: string;
  reason?: string;
}

export interface AgentChatResponse {
  content: string;
  model: string;
  actions: ProposedAction[];
}
