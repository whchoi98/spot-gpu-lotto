import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { TemplateEntry } from "@/lib/types";

interface TemplateSelectorProps {
  templates: TemplateEntry[];
  onSelect: (template: TemplateEntry) => void;
}

export function TemplateSelector({ templates, onSelect }: TemplateSelectorProps) {
  if (templates.length === 0) return null;
  return (
    <Select onValueChange={(name) => {
      const t = templates.find((t) => t.name === name);
      if (t) onSelect(t);
    }}>
      <SelectTrigger className="w-64"><SelectValue placeholder="Load from template..." /></SelectTrigger>
      <SelectContent>
        {templates.map((t) => <SelectItem key={t.name} value={t.name}>{t.name}</SelectItem>)}
      </SelectContent>
    </Select>
  );
}
