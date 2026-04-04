import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { deleteTemplate, fetchTemplates, saveTemplate } from "@/lib/api";
import type { TemplateEntry } from "@/lib/types";

export function useTemplates() {
  return useQuery({
    queryKey: ["templates"],
    queryFn: fetchTemplates,
  });
}

export function useSaveTemplate() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (t: TemplateEntry) => saveTemplate(t),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["templates"] }),
  });
}

export function useDeleteTemplate() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (name: string) => deleteTemplate(name),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["templates"] }),
  });
}
