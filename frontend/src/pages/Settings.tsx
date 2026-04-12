import { useState } from "react";
import { useTranslation } from "react-i18next";
import { saveWebhookUrl } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Alert, AlertDescription } from "@/components/ui/alert";

export default function Settings() {
  const { t } = useTranslation();
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
      <h1 className="text-2xl font-bold">{t("settings_title")}</h1>

      {saved && (
        <Alert>
          <AlertDescription>{t("settings_saved")}</AlertDescription>
        </Alert>
      )}

      <Card>
        <CardHeader>
          <CardTitle>{t("settings_webhook")}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <p className="text-sm text-muted-foreground">{t("settings_webhook_desc")}</p>
          <div className="space-y-2">
            <Label htmlFor="webhook">{t("settings_webhook_label")}</Label>
            <Input
              id="webhook"
              value={webhookUrl}
              onChange={(e) => setWebhookUrl(e.target.value)}
              placeholder="https://hooks.slack.com/services/..."
              type="url"
            />
          </div>
          <Button onClick={handleSave} disabled={saving || !webhookUrl.trim()}>
            {saving ? t("settings_saving") : t("settings_save")}
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
