import { useQuery } from "@tanstack/react-query";
import { fetchPrices } from "@/lib/api";

export function usePrices(instanceType?: string) {
  return useQuery({
    queryKey: ["prices", instanceType],
    queryFn: () => fetchPrices(instanceType),
    refetchInterval: 30_000,
  });
}
