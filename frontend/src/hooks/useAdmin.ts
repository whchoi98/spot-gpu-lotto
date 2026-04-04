import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  adminForceCancel,
  adminForceRetry,
  fetchAdminJobs,
  fetchAdminRegions,
  fetchAdminStats,
  updateRegionCapacity,
} from "@/lib/api";

export function useAdminStats() {
  return useQuery({
    queryKey: ["admin-stats"],
    queryFn: fetchAdminStats,
    refetchInterval: 10_000,
  });
}

export function useAdminJobs() {
  return useQuery({
    queryKey: ["admin-jobs"],
    queryFn: fetchAdminJobs,
    refetchInterval: 10_000,
  });
}

export function useAdminRegions() {
  return useQuery({
    queryKey: ["admin-regions"],
    queryFn: fetchAdminRegions,
    refetchInterval: 10_000,
  });
}

export function useForceCancel() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (jobId: string) => adminForceCancel(jobId),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["admin-jobs"] }),
  });
}

export function useForceRetry() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (jobId: string) => adminForceRetry(jobId),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["admin-jobs"] }),
  });
}

export function useUpdateCapacity() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ region, capacity }: { region: string; capacity: number }) =>
      updateRegionCapacity(region, capacity),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["admin-regions"] }),
  });
}
