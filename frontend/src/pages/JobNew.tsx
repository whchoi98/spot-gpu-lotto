import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { fetchPrices, fetchTemplates } from "@/lib/api";
import { useSubmitJob } from "@/hooks/useJobs";
import { JobForm } from "@/components/jobs/JobForm";
import { InstanceGuide } from "@/components/guide/InstanceGuide";
import { TemplateSelector } from "@/components/templates/TemplateSelector";
import { FileUpload } from "@/components/upload/FileUpload";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Alert, AlertDescription } from "@/components/ui/alert";
import type { TemplateEntry } from "@/lib/types";

export default function JobNew() {
  const navigate = useNavigate();
  const { data: prices } = useQuery({ queryKey: ["prices"], queryFn: () => fetchPrices() });
  const { data: templates } = useQuery({ queryKey: ["templates"], queryFn: fetchTemplates });
  const submitJob = useSubmitJob();
  const [selectedTemplate, setSelectedTemplate] = useState<Partial<TemplateEntry> | undefined>();
  const [selectedInstance, setSelectedInstance] = useState("g6.xlarge");
  const [submitted, setSubmitted] = useState(false);

  function handleTemplateSelect(t: TemplateEntry) {
    setSelectedTemplate(t);
    setSelectedInstance(t.instance_type);
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Submit New Job</h1>
      {submitted && <Alert><AlertDescription>Job submitted to queue. Redirecting to jobs list...</AlertDescription></Alert>}
      <div className="grid gap-6 lg:grid-cols-2">
        <div className="space-y-6">
          <Card>
            <CardHeader><CardTitle>Instance Selection Guide</CardTitle></CardHeader>
            <CardContent>
              <InstanceGuide prices={prices ?? []} selectedInstance={selectedInstance}
                onSelect={(inst) => {
                  setSelectedInstance(inst);
                  setSelectedTemplate((prev) => prev ? { ...prev, instance_type: inst } : { instance_type: inst });
                }} />
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle>File Upload</CardTitle></CardHeader>
            <CardContent><FileUpload prefix="models" /></CardContent>
          </Card>
        </div>
        <Card>
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle>Job Configuration</CardTitle>
              <TemplateSelector templates={templates ?? []} onSelect={handleTemplateSelect} />
            </div>
          </CardHeader>
          <CardContent>
            <JobForm key={selectedTemplate?.name ?? selectedInstance}
              initialValues={{ ...selectedTemplate, instance_type: selectedInstance }}
              isSubmitting={submitJob.isPending}
              onSubmit={(req) => {
                submitJob.mutate(req, {
                  onSuccess: () => { setSubmitted(true); setTimeout(() => navigate("/jobs"), 1500); },
                });
              }} />
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
