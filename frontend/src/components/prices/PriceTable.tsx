import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import type { PriceEntry } from "@/lib/types";

const REGION_LABELS: Record<string, string> = {
  "us-east-1": "US East (Virginia)",
  "us-east-2": "US East (Ohio)",
  "us-west-2": "US West (Oregon)",
};

interface PriceTableProps {
  prices: PriceEntry[];
}

export function PriceTable({ prices }: PriceTableProps) {
  const sorted = [...prices].sort((a, b) => a.price - b.price);
  const cheapest = sorted[0]?.price;

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Region</TableHead>
          <TableHead>Instance Type</TableHead>
          <TableHead className="text-right">Price ($/hr)</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {sorted.map((p) => (
          <TableRow key={`${p.region}:${p.instance_type}`}>
            <TableCell>{REGION_LABELS[p.region] ?? p.region}</TableCell>
            <TableCell className="font-mono">{p.instance_type}</TableCell>
            <TableCell className="text-right">
              <span className="font-mono">${p.price.toFixed(4)}</span>
              {p.price === cheapest && (
                <Badge variant="secondary" className="ml-2">Cheapest</Badge>
              )}
            </TableCell>
          </TableRow>
        ))}
        {sorted.length === 0 && (
          <TableRow>
            <TableCell colSpan={3} className="text-center text-muted-foreground">
              No prices available
            </TableCell>
          </TableRow>
        )}
      </TableBody>
    </Table>
  );
}
