import { useState } from "react";
import { useTranslation } from "react-i18next";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  DollarSign,
  Shield,
  FileText,
  Bell,
  BarChart3,
  HardDrive,
  ChevronDown,
  Zap,
  Rocket,
  Search,
  Download,
} from "lucide-react";

const GPU_INSTANCES = [
  { type: "g6.xlarge", gpu: "L4", vram: "24 GB", vcpu: "4", mem: "16 GB", use: "Inference / Light training" },
  { type: "g5.xlarge", gpu: "A10G", vram: "24 GB", vcpu: "4", mem: "16 GB", use: "Training / Fine-tuning" },
  { type: "g6e.xlarge", gpu: "L40S", vram: "48 GB", vcpu: "4", mem: "16 GB", use: "LLM / Large models" },
  { type: "g6e.2xlarge", gpu: "L40S", vram: "48 GB", vcpu: "8", mem: "32 GB", use: "Multi-task training" },
  { type: "g5.12xlarge", gpu: "4x A10G", vram: "96 GB", vcpu: "48", mem: "192 GB", use: "Distributed training" },
  { type: "g5.48xlarge", gpu: "8x A10G", vram: "192 GB", vcpu: "192", mem: "768 GB", use: "Large-scale training" },
];

const FEATURE_ICONS = [DollarSign, Shield, FileText, Bell, BarChart3, HardDrive];

function FaqItem({ q, a }: { q: string; a: string }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="border-b border-border/50 last:border-0">
      <button
        onClick={() => setOpen(!open)}
        className="flex w-full items-center justify-between py-4 text-left text-sm font-medium transition-colors hover:text-[hsl(var(--sidebar-accent))]"
      >
        {q}
        <ChevronDown
          className={`h-4 w-4 shrink-0 text-muted-foreground transition-transform ${open ? "rotate-180" : ""}`}
        />
      </button>
      {open && <p className="pb-4 text-sm text-muted-foreground leading-relaxed">{a}</p>}
    </div>
  );
}

export default function Guide() {
  const { t } = useTranslation();
  const features = [
    { key: "spot", icon: 0 },
    { key: "checkpoint", icon: 1 },
    { key: "templates", icon: 2 },
    { key: "webhook", icon: 3 },
    { key: "monitoring", icon: 4 },
    { key: "s3", icon: 5 },
  ];
  const faq = t("guide_faq", { returnObjects: true }) as { q: string; a: string }[];
  const howSteps = t("guide_how_steps", { returnObjects: true }) as string[];
  const stepIcons = [Search, Rocket, Download];

  return (
    <div className="mx-auto max-w-4xl space-y-8">
      {/* Hero */}
      <div className="rounded-xl bg-gradient-to-r from-blue-600 to-violet-600 p-8 text-white">
        <h1 className="text-3xl font-bold">{t("guide_title")}</h1>
        <p className="mt-2 text-blue-100">{t("guide_subtitle")}</p>
      </div>

      {/* What is GPU Spot Lotto */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Zap className="h-5 w-5 text-yellow-500" />
            {t("guide_what_title")}
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm leading-relaxed text-muted-foreground">{t("guide_what_desc")}</p>
        </CardContent>
      </Card>

      {/* How It Works */}
      <Card>
        <CardHeader>
          <CardTitle>{t("guide_how_title")}</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 sm:grid-cols-2">
            {howSteps.map((step, i) => (
              <div key={i} className="flex gap-3 rounded-lg border border-border/50 p-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-blue-500 to-violet-600 text-sm font-bold text-white">
                  {i + 1}
                </div>
                <p className="text-sm leading-relaxed text-muted-foreground">{step}</p>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Quick Start */}
      <div>
        <h2 className="mb-4 text-xl font-bold">{t("guide_quickstart_title")}</h2>
        <div className="grid gap-4 sm:grid-cols-3">
          {[1, 2, 3].map((n) => {
            const Icon = stepIcons[n - 1]!;
            return (
              <Card key={n}>
                <CardHeader className="pb-2">
                  <div className="flex items-center gap-2">
                    <Icon className="h-4 w-4 text-blue-500" />
                    <CardTitle className="text-sm">
                      {t(`guide_step${n}_title` as "guide_step1_title")}
                    </CardTitle>
                  </div>
                </CardHeader>
                <CardContent>
                  <p className="text-xs leading-relaxed text-muted-foreground">
                    {t(`guide_step${n}_desc` as "guide_step1_desc")}
                  </p>
                </CardContent>
              </Card>
            );
          })}
        </div>
      </div>

      {/* GPU Instances */}
      <Card>
        <CardHeader>
          <CardTitle>{t("guide_instances_title")}</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-left text-xs font-medium text-muted-foreground">
                  <th className="pb-2 pr-4">{t("guide_col_type")}</th>
                  <th className="pb-2 pr-4">{t("guide_col_gpu")}</th>
                  <th className="pb-2 pr-4">{t("guide_col_vram")}</th>
                  <th className="pb-2 pr-4">{t("guide_col_vcpu")}</th>
                  <th className="pb-2 pr-4">{t("guide_col_mem")}</th>
                  <th className="pb-2">{t("guide_col_use")}</th>
                </tr>
              </thead>
              <tbody>
                {GPU_INSTANCES.map((inst) => (
                  <tr key={inst.type} className="border-b border-border/50 last:border-0">
                    <td className="py-2.5 pr-4 font-mono text-xs font-medium">{inst.type}</td>
                    <td className="py-2.5 pr-4 text-xs">{inst.gpu}</td>
                    <td className="py-2.5 pr-4 text-xs">{inst.vram}</td>
                    <td className="py-2.5 pr-4 text-xs">{inst.vcpu}</td>
                    <td className="py-2.5 pr-4 text-xs">{inst.mem}</td>
                    <td className="py-2.5 text-xs text-muted-foreground">{inst.use}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>

      {/* Features */}
      <div>
        <h2 className="mb-4 text-xl font-bold">{t("guide_features_title")}</h2>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {features.map(({ key, icon }) => {
            const Icon = FEATURE_ICONS[icon]!;
            return (
              <Card key={key} className="group transition-shadow hover:shadow-md">
                <CardContent className="pt-6">
                  <div className="mb-3 flex h-10 w-10 items-center justify-center rounded-lg bg-accent">
                    <Icon className="h-5 w-5 text-[hsl(var(--sidebar-accent))]" />
                  </div>
                  <h3 className="mb-1 text-sm font-semibold">
                    {t(`guide_feat_${key}` as "guide_feat_spot")}
                  </h3>
                  <p className="text-xs leading-relaxed text-muted-foreground">
                    {t(`guide_feat_${key}_desc` as "guide_feat_spot_desc")}
                  </p>
                </CardContent>
              </Card>
            );
          })}
        </div>
      </div>

      {/* FAQ */}
      <Card>
        <CardHeader>
          <CardTitle>{t("guide_faq_title")}</CardTitle>
        </CardHeader>
        <CardContent>
          {faq.map((item, i) => (
            <FaqItem key={i} q={item.q} a={item.a} />
          ))}
        </CardContent>
      </Card>
    </div>
  );
}
