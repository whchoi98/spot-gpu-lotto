import { useState } from "react";
import { saveWebhookUrl } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Alert, AlertDescription } from "@/components/ui/alert";

export default function Settings() {
  const [webhookUrl, setWebhookUrl] = useState("");
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  async function handleSave() {
    if (!webhookUrl.trim()) return;
    setSaving(true);
    setSaved(false);
    try {
      await saveWebhookUrl(webhookUrl.trim());
      setSaved(true);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Settings</h1>

      {saved && (
        <Alert>
          <AlertDescription>Webhook URL saved successfully.</AlertDescription>
        </Alert>
      )}

      <Card>
        <CardHeader>
          <CardTitle>Webhook Notifications</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <p className="text-sm text-muted-foreground">
            Set a default webhook URL to receive notifications when jobs complete or fail.
            This URL will be used for all new job submissions unless overridden.
          </p>
          <div className="space-y-2">
            <Label htmlFor="webhook">Webhook URL</Label>
            <Input
              id="webhook"
              value={webhookUrl}
              onChange={(e) => setWebhookUrl(e.target.value)}
              placeholder="https://hooks.slack.com/services/..."
              type="url"
            />
          </div>
          <Button onClick={handleSave} disabled={saving || !webhookUrl.trim()}>
            {saving ? "Saving..." : "Save"}
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
