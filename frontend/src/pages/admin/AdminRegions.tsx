import { useState } from "react";
import { useAdminRegions, useUpdateCapacity } from "@/hooks/useAdmin";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

const REGION_LABELS: Record<string, string> = {
  "us-east-1": "US East (Virginia)",
  "us-east-2": "US East (Ohio)",
  "us-west-2": "US West (Oregon)",
};

export default function AdminRegions() {
  const { data: regions } = useAdminRegions();
  const updateMut = useUpdateCapacity();
  const [editing, setEditing] = useState<Record<string, string>>({});

  function handleSave(region: string) {
    const val = parseInt(editing[region] ?? "", 10);
    if (isNaN(val) || val < 0) return;
    updateMut.mutate({ region, capacity: val }, {
      onSuccess: () => setEditing((prev) => {
        const next = { ...prev };
        delete next[region];
        return next;
      }),
    });
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Region Management</h1>

      <div className="grid gap-4 md:grid-cols-3">
        {(regions ?? []).map((r) => (
          <Card key={r.region}>
            <CardHeader>
              <CardTitle className="text-base">
                {REGION_LABELS[r.region] ?? r.region}
              </CardTitle>
              <div className="text-xs text-muted-foreground font-mono">{r.region}</div>
            </CardHeader>
            <CardContent className="space-y-3">
              <div>
                <div className="text-3xl font-bold">{r.available_capacity}</div>
                <div className="text-xs text-muted-foreground">GPU slots available</div>
              </div>
              <div className="space-y-2">
                <Label>Set Capacity</Label>
                <div className="flex gap-2">
                  <Input
                    type="number"
                    min={0}
                    value={editing[r.region] ?? ""}
                    onChange={(e) =>
                      setEditing((prev) => ({ ...prev, [r.region]: e.target.value }))
                    }
                    placeholder={String(r.available_capacity)}
                    className="w-24"
                  />
                  <Button
                    size="sm"
                    onClick={() => handleSave(r.region)}
                    disabled={updateMut.isPending || !editing[r.region]}
                  >
                    Update
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
