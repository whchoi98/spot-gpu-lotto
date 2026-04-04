import { useState } from "react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { JobRequest, TemplateEntry } from "@/lib/types";

interface JobFormProps {
  initialValues?: Partial<TemplateEntry>;
  onSubmit: (req: JobRequest) => void;
  isSubmitting: boolean;
}

const GPU_MAP: Record<string, { type: string; count: number }> = {
  "g6.xlarge": { type: "l4", count: 1 },
  "g5.xlarge": { type: "a10g", count: 1 },
  "g6e.xlarge": { type: "l40s", count: 1 },
  "g6e.2xlarge": { type: "l40s", count: 1 },
  "g5.12xlarge": { type: "a10g", count: 4 },
  "g5.48xlarge": { type: "a10g", count: 8 },
};

export function JobForm({ initialValues, onSubmit, isSubmitting }: JobFormProps) {
  const [image, setImage] = useState(initialValues?.image ?? "nvidia/cuda:12.0-base");
  const [instanceType, setInstanceType] = useState(initialValues?.instance_type ?? "g6.xlarge");
  const [storageMode, setStorageMode] = useState(initialValues?.storage_mode ?? "s3");
  const [checkpoint, setCheckpoint] = useState(initialValues?.checkpoint_enabled ?? false);
  const [command, setCommand] = useState(initialValues?.command?.join(" ") ?? "nvidia-smi && sleep 60");

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const gpu = GPU_MAP[instanceType] ?? { type: "l4", count: 1 };
    onSubmit({
      image, instance_type: instanceType, gpu_type: gpu.type, gpu_count: gpu.count,
      storage_mode: storageMode, checkpoint_enabled: checkpoint,
      command: ["/bin/sh", "-c", command],
    });
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="space-y-2">
        <Label htmlFor="image">Container Image</Label>
        <Input id="image" value={image} onChange={(e) => setImage(e.target.value)} placeholder="nvidia/cuda:12.0-base" />
      </div>
      <div className="space-y-2">
        <Label htmlFor="instance">Instance Type</Label>
        <Select value={instanceType} onValueChange={setInstanceType}>
          <SelectTrigger id="instance"><SelectValue /></SelectTrigger>
          <SelectContent>
            {Object.keys(GPU_MAP).map((t) => (
              <SelectItem key={t} value={t}>{t} ({GPU_MAP[t]!.count}x {GPU_MAP[t]!.type.toUpperCase()})</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <div className="space-y-2">
        <Label htmlFor="storage">Storage Mode</Label>
        <Select value={storageMode} onValueChange={setStorageMode}>
          <SelectTrigger id="storage"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="s3">S3 Mountpoint</SelectItem>
            <SelectItem value="fsx">FSx for Lustre</SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div className="flex items-center gap-2">
        <input type="checkbox" id="checkpoint" checked={checkpoint} onChange={(e) => setCheckpoint(e.target.checked)} className="h-4 w-4 rounded border" />
        <Label htmlFor="checkpoint">Enable checkpointing</Label>
      </div>
      <div className="space-y-2">
        <Label htmlFor="command">Command</Label>
        <Input id="command" value={command} onChange={(e) => setCommand(e.target.value)} placeholder="nvidia-smi && sleep 60" />
      </div>
      <Button type="submit" disabled={isSubmitting}>{isSubmitting ? "Submitting..." : "Submit Job"}</Button>
    </form>
  );
}
