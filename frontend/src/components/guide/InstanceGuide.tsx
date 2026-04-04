import { Card, CardContent } from "@/components/ui/card";
import type { PriceEntry } from "@/lib/types";
import { cn } from "@/lib/utils";

interface TierInfo {
  tier: number;
  label: string;
  instances: string[];
  gpu: string;
  vram: string;
  useCase: string;
}

const TIERS: TierInfo[] = [
  { tier: 1, label: "Inference / Light", instances: ["g6.xlarge", "g5.xlarge"], gpu: "1x L4 / A10G", vram: "24GB", useCase: "Inference, light training, QLoRA 7B" },
  { tier: 2, label: "LLM Fine-tuning", instances: ["g6e.xlarge", "g6e.2xlarge"], gpu: "1x L40S", vram: "48GB", useCase: "13B+ QLoRA, 7B full fine-tuning" },
  { tier: 3, label: "Distributed Training", instances: ["g5.12xlarge", "g5.48xlarge"], gpu: "4-8x A10G", vram: "96-192GB", useCase: "Large-scale distributed training" },
];

interface InstanceGuideProps {
  prices: PriceEntry[];
  selectedInstance: string;
  onSelect: (instance: string) => void;
}

export function InstanceGuide({ prices, selectedInstance, onSelect }: InstanceGuideProps) {
  const priceMap = new Map(prices.map((p) => [`${p.region}:${p.instance_type}`, p.price]));

  function cheapestPrice(instanceType: string): number | null {
    let min: number | null = null;
    for (const [key, price] of priceMap) {
      if (key.endsWith(`:${instanceType}`)) {
        if (min === null || price < min) min = price;
      }
    }
    return min;
  }

  return (
    <div className="space-y-3">
      <p className="text-sm text-muted-foreground">Not sure which tier? Start with Tier 1.</p>
      {TIERS.map((tier) => (
        <Card key={tier.tier}>
          <CardContent className="py-3">
            <div className="mb-1 text-sm font-semibold">Tier {tier.tier}: {tier.label}</div>
            <div className="mb-2 text-xs text-muted-foreground">{tier.gpu} / {tier.vram} — {tier.useCase}</div>
            <div className="flex flex-wrap gap-2">
              {tier.instances.map((inst) => {
                const price = cheapestPrice(inst);
                return (
                  <button key={inst} type="button" onClick={() => onSelect(inst)}
                    className={cn("rounded border px-3 py-1 text-sm transition-colors hover:bg-accent",
                      selectedInstance === inst && "border-primary bg-accent font-medium")}>
                    <span className="font-mono">{inst}</span>
                    {price !== null && <span className="ml-2 text-xs text-muted-foreground">from ${price.toFixed(3)}/hr</span>}
                  </button>
                );
              })}
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
