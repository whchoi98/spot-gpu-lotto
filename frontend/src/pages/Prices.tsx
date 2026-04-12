import { useState } from "react";
import { useTranslation } from "react-i18next";
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
  const { t } = useTranslation();
  const [filter, setFilter] = useState<string | undefined>(undefined);
  const { data: prices, isLoading } = usePrices(filter);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">{t("prices_title")}</h1>
        <Select
          value={filter ?? "all"}
          onValueChange={(v) => setFilter(v === "all" ? undefined : v)}
        >
          <SelectTrigger className="w-48">
            <SelectValue placeholder={t("prices_all")} />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">{t("prices_all")}</SelectItem>
            {INSTANCE_TYPES.map((tp) => (
              <SelectItem key={tp} value={tp}>{tp}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <p className="text-sm text-muted-foreground">{t("prices_refresh")}</p>
      <Card>
        <CardHeader><CardTitle>{t("prices_current")}</CardTitle></CardHeader>
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
