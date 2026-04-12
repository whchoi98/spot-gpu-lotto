import i18n from "i18next";
import { initReactI18next } from "react-i18next";

const en = {
  // nav
  nav_dashboard: "Dashboard",
  nav_jobs: "Jobs",
  nav_new_job: "New Job",
  nav_prices: "Spot Prices",
  nav_templates: "Templates",
  nav_settings: "Settings",
  nav_guide: "Guide",
  nav_monitoring: "Monitoring",
  nav_admin: "Admin",
  nav_admin_dashboard: "Admin Dashboard",
  nav_admin_jobs: "All Jobs",
  nav_admin_regions: "Regions",

  // header
  theme_light: "Light",
  theme_dark: "Dark",

  // dashboard
  dash_title: "Dashboard",
  dash_active_jobs: "Active Jobs",
  dash_queue_depth: "Queue Depth",
  dash_cheapest: "Cheapest Spot",
  dash_recent_jobs: "Recent Jobs",
  dash_spot_prices: "Spot Prices",
  dash_new_job: "New Job",
  dash_no_jobs: "No jobs yet",
  dash_regions: "3 Regions",
  dash_per_hr: "/hr",

  // prices
  prices_title: "Spot Prices",
  prices_all: "All instances",
  prices_refresh: "Prices refresh every 30 seconds. Sorted cheapest-first.",
  prices_current: "Current Spot Prices (3 Regions)",

  // jobs
  jobs_title: "My Jobs",
  jobs_history: "Job History",

  // settings
  settings_title: "Settings",
  settings_webhook: "Webhook Notifications",
  settings_webhook_desc:
    "Set a default webhook URL to receive notifications when jobs complete or fail.",
  settings_webhook_label: "Webhook URL",
  settings_save: "Save",
  settings_saving: "Saving...",
  settings_saved: "Webhook URL saved successfully.",

  // guide
  guide_title: "Usage Guide",
  guide_subtitle: "Everything you need to get started with GPU Spot Lotto",
  guide_what_title: "What is GPU Spot Lotto?",
  guide_what_desc:
    "GPU Spot Lotto is a system that monitors GPU Spot instance prices across 3 AWS regions (us-east-1, us-east-2, us-west-2) in real-time and dispatches your workloads to the cheapest available region. It helps you save up to 70-90% on GPU costs compared to on-demand pricing.",
  guide_how_title: "How It Works",
  guide_how_steps: [
    "Submit a GPU job with your container image and configuration",
    "The system monitors Spot prices across 3 AWS regions in real-time",
    "Your job is dispatched to the cheapest available region",
    "Monitor progress, view logs, and download results from S3",
  ],
  guide_quickstart_title: "Quick Start",
  guide_step1_title: "1. Choose an Instance Type",
  guide_step1_desc:
    "Browse the Spot Prices page to see current pricing across all regions.",
  guide_step2_title: "2. Submit a Job",
  guide_step2_desc:
    'Click "New Job" to configure your GPU workload. Specify your Docker image, command, GPU type and count.',
  guide_step3_title: "3. Monitor & Collect Results",
  guide_step3_desc:
    "Track job status in real-time. When complete, results are uploaded to S3.",
  guide_instances_title: "GPU Instance Types",
  guide_col_type: "Instance Type",
  guide_col_gpu: "GPU",
  guide_col_vram: "VRAM",
  guide_col_vcpu: "vCPU",
  guide_col_mem: "Memory",
  guide_col_use: "Best For",
  guide_features_title: "Key Features",
  guide_feat_spot: "Smart Spot Pricing",
  guide_feat_spot_desc: "Automatic multi-region price comparison and dispatch to the cheapest region",
  guide_feat_checkpoint: "Checkpoint & Recovery",
  guide_feat_checkpoint_desc:
    "Enable checkpointing to automatically save progress and resume if a Spot instance is reclaimed",
  guide_feat_templates: "Job Templates",
  guide_feat_templates_desc: "Save frequently used configurations as templates for one-click deployment",
  guide_feat_webhook: "Webhook Notifications",
  guide_feat_webhook_desc: "Get notified via Slack or custom webhook when jobs complete or fail",
  guide_feat_monitoring: "Real-time Monitoring",
  guide_feat_monitoring_desc: "Grafana dashboards with live metrics for prices, jobs, and infrastructure",
  guide_feat_s3: "S3 Result Storage",
  guide_feat_s3_desc: "Results automatically uploaded to S3 hub bucket for easy access",
  guide_faq_title: "FAQ",
  guide_faq: [
    {
      q: "What happens if a Spot instance is reclaimed?",
      a: "If checkpointing is enabled, the job automatically resumes from the last checkpoint in the next cheapest region. Otherwise, the job is requeued for retry.",
    },
    {
      q: "How often are Spot prices updated?",
      a: "Prices are fetched every 30 seconds from all 3 regions and cached in Redis.",
    },
    {
      q: "Can I specify a particular region?",
      a: "The system automatically selects the cheapest region, but you can set region preferences through the admin panel.",
    },
    {
      q: "What Docker images are supported?",
      a: "Any Docker image with NVIDIA GPU support. The container must be available in our ECR registry or a public registry.",
    },
    {
      q: "How do I access job results?",
      a: "Results are uploaded to S3 upon completion. The result path is shown on the Job Detail page.",
    },
  ],
};

const ko: typeof en = {
  nav_dashboard: "\uB300\uC2DC\uBCF4\uB4DC",
  nav_jobs: "\uC791\uC5C5",
  nav_new_job: "\uC0C8 \uC791\uC5C5",
  nav_prices: "\uC2A4\uD31F \uAC00\uACA9",
  nav_templates: "\uD15C\uD50C\uB9BF",
  nav_settings: "\uC124\uC815",
  nav_guide: "\uC0AC\uC6A9 \uAC00\uC774\uB4DC",
  nav_monitoring: "\uBAA8\uB2C8\uD130\uB9C1",
  nav_admin: "\uAD00\uB9AC\uC790",
  nav_admin_dashboard: "\uAD00\uB9AC \uB300\uC2DC\uBCF4\uB4DC",
  nav_admin_jobs: "\uC804\uCCB4 \uC791\uC5C5",
  nav_admin_regions: "\uB9AC\uC804",

  theme_light: "\uB77C\uC774\uD2B8",
  theme_dark: "\uB2E4\uD06C",

  dash_title: "\uB300\uC2DC\uBCF4\uB4DC",
  dash_active_jobs: "\uD65C\uC131 \uC791\uC5C5",
  dash_queue_depth: "\uB300\uAE30\uC5F4",
  dash_cheapest: "\uCD5C\uC800 \uAC00\uACA9",
  dash_recent_jobs: "\uCD5C\uADFC \uC791\uC5C5",
  dash_spot_prices: "\uC2A4\uD31F \uAC00\uACA9",
  dash_new_job: "\uC0C8 \uC791\uC5C5",
  dash_no_jobs: "\uC544\uC9C1 \uC791\uC5C5\uC774 \uC5C6\uC2B5\uB2C8\uB2E4",
  dash_regions: "3\uAC1C \uB9AC\uC804",
  dash_per_hr: "/\uC2DC\uAC04",

  prices_title: "\uC2A4\uD31F \uAC00\uACA9",
  prices_all: "\uC804\uCCB4 \uC778\uC2A4\uD134\uC2A4",
  prices_refresh: "30\uCD08\uB9C8\uB2E4 \uAC00\uACA9\uC774 \uC0C8\uB85C\uACE0\uCE68\uB429\uB2C8\uB2E4. \uCD5C\uC800\uAC00 \uC21C\uC73C\uB85C \uC815\uB82C\uB429\uB2C8\uB2E4.",
  prices_current: "\uD604\uC7AC \uC2A4\uD31F \uAC00\uACA9 (3\uAC1C \uB9AC\uC804)",

  jobs_title: "\uB0B4 \uC791\uC5C5",
  jobs_history: "\uC791\uC5C5 \uAE30\uB85D",

  settings_title: "\uC124\uC815",
  settings_webhook: "\uC6F9\uD6C5 \uC54C\uB9BC",
  settings_webhook_desc:
    "\uC791\uC5C5 \uC644\uB8CC \uB610\uB294 \uC2E4\uD328 \uC2DC \uC54C\uB9BC\uC744 \uBC1B\uC744 \uAE30\uBCF8 \uC6F9\uD6C5 URL\uC744 \uC124\uC815\uD558\uC138\uC694.",
  settings_webhook_label: "\uC6F9\uD6C5 URL",
  settings_save: "\uC800\uC7A5",
  settings_saving: "\uC800\uC7A5 \uC911...",
  settings_saved: "\uC6F9\uD6C5 URL\uC774 \uC800\uC7A5\uB418\uC5C8\uC2B5\uB2C8\uB2E4.",

  guide_title: "\uC0AC\uC6A9 \uAC00\uC774\uB4DC",
  guide_subtitle: "GPU Spot Lotto\uB97C \uC2DC\uC791\uD558\uAE30 \uC704\uD55C \uBAA8\uB4E0 \uAC83",
  guide_what_title: "GPU Spot Lotto\uB780?",
  guide_what_desc:
    "GPU Spot Lotto\uB294 3\uAC1C AWS \uB9AC\uC804(us-east-1, us-east-2, us-west-2)\uC758 GPU \uC2A4\uD31F \uC778\uC2A4\uD134\uC2A4 \uAC00\uACA9\uC744 \uC2E4\uC2DC\uAC04\uC73C\uB85C \uBAA8\uB2C8\uD130\uB9C1\uD558\uACE0, \uAC00\uC7A5 \uC800\uB834\uD55C \uB9AC\uC804\uC73C\uB85C \uC791\uC5C5\uC744 \uBC30\uCE58\uD558\uB294 \uC2DC\uC2A4\uD15C\uC785\uB2C8\uB2E4. \uC628\uB514\uB9E8\uB4DC \uB300\uBE44 70~90%\uC758 GPU \uBE44\uC6A9\uC744 \uC808\uAC10\uD560 \uC218 \uC788\uC2B5\uB2C8\uB2E4.",
  guide_how_title: "\uC791\uB3D9 \uBC29\uC2DD",
  guide_how_steps: [
    "\uCEE8\uD14C\uC774\uB108 \uC774\uBBF8\uC9C0\uC640 \uC124\uC815\uC73C\uB85C GPU \uC791\uC5C5\uC744 \uC81C\uCD9C\uD569\uB2C8\uB2E4",
    "\uC2DC\uC2A4\uD15C\uC774 3\uAC1C AWS \uB9AC\uC804\uC758 \uC2A4\uD31F \uAC00\uACA9\uC744 \uC2E4\uC2DC\uAC04 \uBAA8\uB2C8\uD130\uB9C1\uD569\uB2C8\uB2E4",
    "\uAC00\uC7A5 \uC800\uB834\uD55C \uB9AC\uC804\uC73C\uB85C \uC791\uC5C5\uC774 \uBC30\uCE58\uB429\uB2C8\uB2E4",
    "\uC9C4\uD589 \uC0C1\uD669\uC744 \uBAA8\uB2C8\uD130\uB9C1\uD558\uACE0, S3\uC5D0\uC11C \uACB0\uACFC\uB97C \uB2E4\uC6B4\uB85C\uB4DC\uD569\uB2C8\uB2E4",
  ],
  guide_quickstart_title: "\uBE60\uB978 \uC2DC\uC791",
  guide_step1_title: "1. \uC778\uC2A4\uD134\uC2A4 \uD0C0\uC785 \uC120\uD0DD",
  guide_step1_desc:
    "\uC2A4\uD31F \uAC00\uACA9 \uD398\uC774\uC9C0\uC5D0\uC11C \uBAA8\uB4E0 \uB9AC\uC804\uC758 \uD604\uC7AC \uAC00\uACA9\uC744 \uD655\uC778\uD558\uC138\uC694.",
  guide_step2_title: "2. \uC791\uC5C5 \uC81C\uCD9C",
  guide_step2_desc:
    '"\uC0C8 \uC791\uC5C5"\uC744 \uD074\uB9AD\uD558\uC5EC GPU \uC791\uC5C5\uC744 \uC124\uC815\uD558\uC138\uC694. Docker \uC774\uBBF8\uC9C0, \uBA85\uB839\uC5B4, GPU \uD0C0\uC785\uACFC \uC218\uB7C9\uC744 \uC9C0\uC815\uD569\uB2C8\uB2E4.',
  guide_step3_title: "3. \uBAA8\uB2C8\uD130\uB9C1 & \uACB0\uACFC \uC218\uC9D1",
  guide_step3_desc:
    "\uC791\uC5C5 \uC0C1\uD0DC\uB97C \uC2E4\uC2DC\uAC04\uC73C\uB85C \uCD94\uC801\uD569\uB2C8\uB2E4. \uC644\uB8CC \uC2DC \uACB0\uACFC\uAC00 S3\uC5D0 \uC5C5\uB85C\uB4DC\uB429\uB2C8\uB2E4.",
  guide_instances_title: "GPU \uC778\uC2A4\uD134\uC2A4 \uD0C0\uC785",
  guide_col_type: "\uC778\uC2A4\uD134\uC2A4",
  guide_col_gpu: "GPU",
  guide_col_vram: "VRAM",
  guide_col_vcpu: "vCPU",
  guide_col_mem: "\uBA54\uBAA8\uB9AC",
  guide_col_use: "\uCD94\uCC9C \uC6A9\uB3C4",
  guide_features_title: "\uC8FC\uC694 \uAE30\uB2A5",
  guide_feat_spot: "\uC2A4\uB9C8\uD2B8 \uC2A4\uD31F \uAC00\uACA9",
  guide_feat_spot_desc: "\uBA40\uD2F0 \uB9AC\uC804 \uC790\uB3D9 \uAC00\uACA9 \uBE44\uAD50 \uBC0F \uCD5C\uC800\uAC00 \uB9AC\uC804\uC73C\uB85C \uBC30\uCE58",
  guide_feat_checkpoint: "\uCCB4\uD06C\uD3EC\uC778\uD2B8 & \uBCF5\uAD6C",
  guide_feat_checkpoint_desc:
    "\uCCB4\uD06C\uD3EC\uC778\uD2B8\uB97C \uD65C\uC131\uD654\uD558\uBA74 \uC2A4\uD31F \uC778\uC2A4\uD134\uC2A4 \uD68C\uC218 \uC2DC \uC790\uB3D9\uC73C\uB85C \uC9C4\uD589 \uC0C1\uD669\uC744 \uC800\uC7A5\uD558\uACE0 \uC7AC\uAC1C\uD569\uB2C8\uB2E4",
  guide_feat_templates: "\uC791\uC5C5 \uD15C\uD50C\uB9BF",
  guide_feat_templates_desc: "\uC790\uC8FC \uC0AC\uC6A9\uD558\uB294 \uC124\uC815\uC744 \uD15C\uD50C\uB9BF\uC73C\uB85C \uC800\uC7A5\uD558\uC5EC \uD55C \uBC88\uC758 \uD074\uB9AD\uC73C\uB85C \uBC30\uD3EC",
  guide_feat_webhook: "\uC6F9\uD6C5 \uC54C\uB9BC",
  guide_feat_webhook_desc: "\uC791\uC5C5 \uC644\uB8CC \uB610\uB294 \uC2E4\uD328 \uC2DC Slack\uC774\uB098 \uCEE4\uC2A4\uD140 \uC6F9\uD6C5\uC73C\uB85C \uC54C\uB9BC",
  guide_feat_monitoring: "\uC2E4\uC2DC\uAC04 \uBAA8\uB2C8\uD130\uB9C1",
  guide_feat_monitoring_desc: "\uAC00\uACA9, \uC791\uC5C5, \uC778\uD504\uB77C\uC5D0 \uB300\uD55C \uC2E4\uC2DC\uAC04 Grafana \uB300\uC2DC\uBCF4\uB4DC",
  guide_feat_s3: "S3 \uACB0\uACFC \uC800\uC7A5\uC18C",
  guide_feat_s3_desc: "\uACB0\uACFC\uAC00 S3 \uD5C8\uBE0C \uBC84\uD0B7\uC5D0 \uC790\uB3D9 \uC5C5\uB85C\uB4DC\uB418\uC5B4 \uC27D\uAC8C \uC811\uADFC \uAC00\uB2A5",
  guide_faq_title: "\uC790\uC8FC \uBB3B\uB294 \uC9C8\uBB38",
  guide_faq: [
    {
      q: "\uC2A4\uD31F \uC778\uC2A4\uD134\uC2A4\uAC00 \uD68C\uC218\uB418\uBA74 \uC5B4\uB5BB\uAC8C \uB418\uB098\uC694?",
      a: "\uCCB4\uD06C\uD3EC\uC778\uD2B8\uAC00 \uD65C\uC131\uD654\uB418\uC5B4 \uC788\uC73C\uBA74 \uB9C8\uC9C0\uB9C9 \uCCB4\uD06C\uD3EC\uC778\uD2B8\uBD80\uD130 \uB2E4\uC74C \uCD5C\uC800\uAC00 \uB9AC\uC804\uC5D0\uC11C \uC790\uB3D9 \uC7AC\uAC1C\uB429\uB2C8\uB2E4. \uADF8\uB807\uC9C0 \uC54A\uC73C\uBA74 \uC791\uC5C5\uC774 \uC7AC\uC2DC\uB3C4 \uB300\uAE30\uC5F4\uC5D0 \uB4E4\uC5B4\uAC11\uB2C8\uB2E4.",
    },
    {
      q: "\uC2A4\uD31F \uAC00\uACA9\uC740 \uC5BC\uB9C8\uB098 \uC790\uC8FC \uC5C5\uB370\uC774\uD2B8\uB418\uB098\uC694?",
      a: "3\uAC1C \uB9AC\uC804\uC5D0\uC11C 30\uCD08\uB9C8\uB2E4 \uAC00\uACA9\uC744 \uC218\uC9D1\uD558\uC5EC Redis\uC5D0 \uCE90\uC2DC\uD569\uB2C8\uB2E4.",
    },
    {
      q: "\uD2B9\uC815 \uB9AC\uC804\uC744 \uC9C0\uC815\uD560 \uC218 \uC788\uB098\uC694?",
      a: "\uC2DC\uC2A4\uD15C\uC774 \uC790\uB3D9\uC73C\uB85C \uCD5C\uC800\uAC00 \uB9AC\uC804\uC744 \uC120\uD0DD\uD558\uC9C0\uB9CC, \uAD00\uB9AC\uC790 \uD328\uB110\uC5D0\uC11C \uB9AC\uC804 \uC120\uD638\uB3C4\uB97C \uC124\uC815\uD560 \uC218 \uC788\uC2B5\uB2C8\uB2E4.",
    },
    {
      q: "\uC5B4\uB5A4 Docker \uC774\uBBF8\uC9C0\uB97C \uC9C0\uC6D0\uD558\uB098\uC694?",
      a: "NVIDIA GPU \uC9C0\uC6D0 Docker \uC774\uBBF8\uC9C0\uB77C\uBA74 \uBAA8\uB450 \uAC00\uB2A5\uD569\uB2C8\uB2E4. ECR \uB808\uC9C0\uC2A4\uD2B8\uB9AC \uB610\uB294 \uACF5\uAC1C \uB808\uC9C0\uC2A4\uD2B8\uB9AC\uC5D0\uC11C \uC811\uADFC \uAC00\uB2A5\uD574\uC57C \uD569\uB2C8\uB2E4.",
    },
    {
      q: "\uC791\uC5C5 \uACB0\uACFC\uC5D0 \uC5B4\uB5BB\uAC8C \uC811\uADFC\uD558\uB098\uC694?",
      a: "\uC791\uC5C5 \uC644\uB8CC \uC2DC \uACB0\uACFC\uAC00 S3\uC5D0 \uC5C5\uB85C\uB4DC\uB429\uB2C8\uB2E4. \uC791\uC5C5 \uC0C1\uC138 \uD398\uC774\uC9C0\uC5D0\uC11C \uACB0\uACFC \uACBD\uB85C\uB97C \uD655\uC778\uD560 \uC218 \uC788\uC2B5\uB2C8\uB2E4.",
    },
  ],
};

i18n.use(initReactI18next).init({
  resources: {
    en: { translation: en },
    ko: { translation: ko },
  },
  lng: localStorage.getItem("lang") || "ko",
  fallbackLng: "en",
  interpolation: { escapeValue: false },
});

export default i18n;
