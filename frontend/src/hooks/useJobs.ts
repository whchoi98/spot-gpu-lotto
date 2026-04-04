import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { cancelJob, fetchJob, submitJob } from "@/lib/api";
import type { JobRequest } from "@/lib/types";

export function useJob(jobId: string) {
  return useQuery({
    queryKey: ["job", jobId],
    queryFn: () => fetchJob(jobId),
    refetchInterval: 5_000,
  });
}

export function useSubmitJob() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (req: JobRequest) => submitJob(req),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["admin-stats"] }),
  });
}

export function useCancelJob() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (jobId: string) => cancelJob(jobId),
    onSuccess: (_data, jobId) => {
      qc.invalidateQueries({ queryKey: ["job", jobId] });
    },
  });
}
