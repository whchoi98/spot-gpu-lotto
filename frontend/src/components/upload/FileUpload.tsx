import { useCallback, useState } from "react";
import { presignUpload } from "@/lib/api";
import { Upload } from "lucide-react";

interface FileUploadProps {
  prefix?: string;
  onUploaded?: (path: string) => void;
}

export function FileUpload({ prefix = "models", onUploaded }: FileUploadProps) {
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [filename, setFilename] = useState<string | null>(null);

  const handleFile = useCallback(async (file: File) => {
    setUploading(true);
    setFilename(file.name);
    setProgress(0);
    try {
      const { url, fields } = await presignUpload(file.name, prefix);
      const form = new FormData();
      Object.entries(fields).forEach(([k, v]) => form.append(k, v));
      form.append("file", file);
      const xhr = new XMLHttpRequest();
      xhr.upload.addEventListener("progress", (e) => {
        if (e.lengthComputable) setProgress(Math.round((e.loaded / e.total) * 100));
      });
      await new Promise<void>((resolve, reject) => {
        xhr.onload = () => (xhr.status < 400 ? resolve() : reject(new Error("Upload failed")));
        xhr.onerror = () => reject(new Error("Upload failed"));
        xhr.open("POST", url);
        xhr.send(form);
      });
      const path = `s3://${prefix}/${file.name}`;
      onUploaded?.(path);
    } finally {
      setUploading(false);
    }
  }, [prefix, onUploaded]);

  return (
    <div className="rounded-md border-2 border-dashed p-4 text-center"
      onDragOver={(e) => e.preventDefault()}
      onDrop={(e) => { e.preventDefault(); const file = e.dataTransfer.files[0]; if (file) handleFile(file); }}>
      {uploading ? (
        <div className="space-y-1">
          <p className="text-sm">{filename} — {progress}%</p>
          <div className="mx-auto h-2 w-48 overflow-hidden rounded-full bg-secondary">
            <div className="h-full bg-primary transition-all" style={{ width: `${progress}%` }} />
          </div>
        </div>
      ) : (
        <>
          <Upload className="mx-auto mb-2 h-6 w-6 text-muted-foreground" />
          <p className="text-sm text-muted-foreground">
            Drag & drop or{" "}
            <label className="cursor-pointer text-primary underline">
              browse
              <input type="file" className="hidden" onChange={(e) => { const file = e.target.files?.[0]; if (file) handleFile(file); }} />
            </label>
          </p>
        </>
      )}
    </div>
  );
}
