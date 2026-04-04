import { useState } from "react";
import { useTemplates, useSaveTemplate, useDeleteTemplate } from "@/hooks/useTemplates";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Skeleton } from "@/components/ui/skeleton";
import { Trash2 } from "lucide-react";

export default function Templates() {
  const { data: templates, isLoading } = useTemplates();
  const saveMut = useSaveTemplate();
  const deleteMut = useDeleteTemplate();

  const [name, setName] = useState("");
  const [image, setImage] = useState("nvidia/cuda:12.0-base");
  const [instanceType, setInstanceType] = useState("g6.xlarge");
  const [storageMode, setStorageMode] = useState("s3");
  const [checkpoint, setCheckpoint] = useState(false);
  const [command, setCommand] = useState("nvidia-smi && sleep 60");

  function handleSave() {
    if (!name.trim()) return;
    saveMut.mutate({
      name: name.trim(),
      image,
      instance_type: instanceType,
      gpu_count: 1,
      gpu_type: "l4",
      storage_mode: storageMode,
      checkpoint_enabled: checkpoint,
      command: ["/bin/sh", "-c", command],
    });
    setName("");
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Job Templates</h1>

      <Card>
        <CardHeader>
          <CardTitle>Create Template</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label>Template Name</Label>
              <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="My Template" />
            </div>
            <div className="space-y-2">
              <Label>Image</Label>
              <Input value={image} onChange={(e) => setImage(e.target.value)} />
            </div>
            <div className="space-y-2">
              <Label>Instance Type</Label>
              <Select value={instanceType} onValueChange={setInstanceType}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {["g6.xlarge","g5.xlarge","g6e.xlarge","g6e.2xlarge","g5.12xlarge","g5.48xlarge"].map((t) => (
                    <SelectItem key={t} value={t}>{t}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>Storage</Label>
              <Select value={storageMode} onValueChange={setStorageMode}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="s3">S3</SelectItem>
                  <SelectItem value="fsx">FSx</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2 sm:col-span-2">
              <Label>Command</Label>
              <Input value={command} onChange={(e) => setCommand(e.target.value)} />
            </div>
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="tpl-checkpoint"
                checked={checkpoint}
                onChange={(e) => setCheckpoint(e.target.checked)}
                className="h-4 w-4 rounded border"
              />
              <Label htmlFor="tpl-checkpoint">Checkpoint</Label>
            </div>
            <div className="flex items-end">
              <Button onClick={handleSave} disabled={saveMut.isPending || !name.trim()}>
                Save Template
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>My Templates</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="space-y-2">
              {Array.from({ length: 3 }).map((_, i) => (
                <Skeleton key={i} className="h-10 w-full" />
              ))}
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Image</TableHead>
                  <TableHead>Instance</TableHead>
                  <TableHead>Storage</TableHead>
                  <TableHead />
                </TableRow>
              </TableHeader>
              <TableBody>
                {(templates ?? []).map((t) => (
                  <TableRow key={t.name}>
                    <TableCell className="font-medium">{t.name}</TableCell>
                    <TableCell className="font-mono text-sm">{t.image}</TableCell>
                    <TableCell className="font-mono text-sm">{t.instance_type}</TableCell>
                    <TableCell>{t.storage_mode}</TableCell>
                    <TableCell>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => deleteMut.mutate(t.name)}
                        disabled={deleteMut.isPending}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
                {(templates ?? []).length === 0 && (
                  <TableRow>
                    <TableCell colSpan={5} className="text-center text-muted-foreground">
                      No templates saved yet
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
