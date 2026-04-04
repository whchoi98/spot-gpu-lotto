import { useState } from "react";
import { usePrices } from "@/hooks/usePrices";
import { PriceTable } from "@/components/prices/PriceTable";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

const INSTANCE_TYPES = [
  "g6.xlarge", "g5.xlarge", "g6e.xlarge", "g6e.2xlarge", "g5.12xlarge", "g5.48xlarge",
];

export default function Prices() {
  const [filter, setFilter] = useState<string | undefined>(undefined);
  const { data: prices, isLoading } = usePrices(filter);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Spot Prices</h1>
        <Select
          value={filter ?? "all"}
          onValueChange={(v) => setFilter(v === "all" ? undefined : v)}
        >
          <SelectTrigger className="w-48">
            <SelectValue placeholder="All instances" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All instances</SelectItem>
            {INSTANCE_TYPES.map((t) => (
              <SelectItem key={t} value={t}>{t}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <p className="text-sm text-muted-foreground">
        Prices refresh every 30 seconds. Sorted cheapest-first.
      </p>
      <Card>
        <CardHeader><CardTitle>Current Spot Prices (3 Regions)</CardTitle></CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="space-y-2">
              {Array.from({ length: 6 }).map((_, i) => (
                <Skeleton key={i} className="h-10 w-full" />
              ))}
            </div>
          ) : (
            <PriceTable prices={prices ?? []} />
          )}
        </CardContent>
      </Card>
    </div>
  );
}
