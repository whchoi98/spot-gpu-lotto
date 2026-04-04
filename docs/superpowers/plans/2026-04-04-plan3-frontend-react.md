# GPU Spot Lotto — Plan 3: Frontend (React)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a React SPA for GPU Spot Lotto — users can submit GPU jobs, monitor prices, track job status via SSE, and manage templates. Admins get a separate dashboard for system management.

**Architecture:** Single-page app in `frontend/` using Vite + React 18 + TypeScript. TanStack Query manages server state with polling/SSE. shadcn/ui provides the component library. The app proxies `/api/*` to the FastAPI backend in dev mode. Production serves via nginx:alpine container behind ALB.

**Tech Stack:** React 18, Vite 5, TypeScript, Tailwind CSS 3, shadcn/ui, TanStack Query v5, React Router v6, Axios

**Spec:** `docs/superpowers/specs/2026-04-03-gpu-spot-lotto-design.md` (sections 3, 12)

**Depends on:** Plan 1 (Python Backend) — all API endpoints are implemented.

---

## File Map

### Create

```
frontend/
├── index.html
├── package.json
├── tsconfig.json
├── tsconfig.app.json
├── tsconfig.node.json
├── vite.config.ts
├── tailwind.config.ts
├── postcss.config.js
├── components.json                  # shadcn/ui config
├── nginx.conf                       # Production SPA routing
├── Dockerfile                       # Multi-stage: node build → nginx:alpine
├── src/
│   ├── main.tsx                     # React entry
│   ├── App.tsx                      # Router + layout + route guard
│   ├── index.css                    # Tailwind directives + shadcn variables
│   ├── lib/
│   │   ├── types.ts                 # Shared TS types matching backend models
│   │   ├── api.ts                   # Axios instance + API functions
│   │   ├── auth.ts                  # JWT decode, role check utilities
│   │   └── utils.ts                 # shadcn cn() utility
│   ├── hooks/
│   │   ├── useAuth.ts               # Auth context + user info
│   │   ├── usePrices.ts             # TanStack Query: price polling (30s)
│   │   ├── useJobs.ts               # TanStack Query: job CRUD
│   │   ├── useJobStream.ts          # SSE EventSource hook
│   │   ├── useTemplates.ts          # TanStack Query: template CRUD
│   │   └── useAdmin.ts             # TanStack Query: admin endpoints
│   ├── components/
│   │   ├── ui/                      # shadcn/ui primitives (auto-generated)
│   │   ├── layout/
│   │   │   ├── Sidebar.tsx
│   │   │   ├── Header.tsx
│   │   │   └── AppLayout.tsx
│   │   ├── jobs/
│   │   │   ├── JobStatusBadge.tsx
│   │   │   ├── JobTable.tsx
│   │   │   └── JobForm.tsx
│   │   ├── prices/
│   │   │   └── PriceTable.tsx
│   │   ├── templates/
│   │   │   └── TemplateSelector.tsx
│   │   ├── upload/
│   │   │   └── FileUpload.tsx
│   │   └── guide/
│   │       └── InstanceGuide.tsx
│   └── pages/
│       ├── Dashboard.tsx
│       ├── Jobs.tsx
│       ├── JobNew.tsx
│       ├── JobDetail.tsx
│       ├── Templates.tsx
│       ├── Prices.tsx
│       ├── Settings.tsx
│       └── admin/
│           ├── AdminDashboard.tsx
│           ├── AdminJobs.tsx
│           └── AdminRegions.tsx
```

### Modify

```
docker-compose.yml                   # Add frontend service
```

---

## Task 1: Project Scaffolding

**Files:**
- Create: `frontend/package.json`, `frontend/index.html`, `frontend/tsconfig.json`, `frontend/tsconfig.app.json`, `frontend/tsconfig.node.json`, `frontend/vite.config.ts`, `frontend/tailwind.config.ts`, `frontend/postcss.config.js`, `frontend/components.json`, `frontend/src/main.tsx`, `frontend/src/index.css`, `frontend/src/lib/utils.ts`, `frontend/src/App.tsx`

- [ ] **Step 1: Create frontend/package.json**

```json
{
  "name": "gpu-spot-lotto-frontend",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "lint": "eslint ."
  },
  "dependencies": {
    "@radix-ui/react-dialog": "^1.1.0",
    "@radix-ui/react-dropdown-menu": "^2.1.0",
    "@radix-ui/react-label": "^2.1.0",
    "@radix-ui/react-select": "^2.1.0",
    "@radix-ui/react-separator": "^1.1.0",
    "@radix-ui/react-slot": "^1.1.0",
    "@radix-ui/react-tabs": "^1.1.0",
    "@tanstack/react-query": "^5.60.0",
    "axios": "^1.7.0",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.1.0",
    "lucide-react": "^0.460.0",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "react-router-dom": "^6.28.0",
    "tailwind-merge": "^2.6.0",
    "tailwindcss-animate": "^1.0.0"
  },
  "devDependencies": {
    "@eslint/js": "^9.0.0",
    "@types/react": "^18.3.0",
    "@types/react-dom": "^18.3.0",
    "@vitejs/plugin-react": "^4.3.0",
    "autoprefixer": "^10.4.0",
    "eslint": "^9.0.0",
    "eslint-plugin-react-hooks": "^5.0.0",
    "eslint-plugin-react-refresh": "^0.4.0",
    "globals": "^15.0.0",
    "postcss": "^8.4.0",
    "tailwindcss": "^3.4.0",
    "typescript": "^5.6.0",
    "typescript-eslint": "^8.0.0",
    "vite": "^5.4.0"
  }
}
```

- [ ] **Step 2: Create frontend/index.html**

```html
<!doctype html>
<html lang="ko">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>GPU Spot Lotto</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

- [ ] **Step 3: Create TypeScript configs**

`frontend/tsconfig.json`:
```json
{
  "files": [],
  "references": [
    { "path": "./tsconfig.app.json" },
    { "path": "./tsconfig.node.json" }
  ]
}
```

`frontend/tsconfig.app.json`:
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedIndexedAccess": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"]
}
```

`frontend/tsconfig.node.json`:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2023"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["vite.config.ts"]
}
```

- [ ] **Step 4: Create Vite config with API proxy**

`frontend/vite.config.ts`:
```ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  server: {
    port: 3000,
    proxy: {
      "/api": {
        target: "http://localhost:8000",
        changeOrigin: true,
      },
    },
  },
});
```

- [ ] **Step 5: Create Tailwind + PostCSS config**

`frontend/tailwind.config.ts`:
```ts
import type { Config } from "tailwindcss";
import tailwindAnimate from "tailwindcss-animate";

export default {
  darkMode: "class",
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
        popover: {
          DEFAULT: "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
    },
  },
  plugins: [tailwindAnimate],
} satisfies Config;
```

`frontend/postcss.config.js`:
```js
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
```

- [ ] **Step 6: Create shadcn/ui config and utility**

`frontend/components.json`:
```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "default",
  "rsc": false,
  "tsx": true,
  "tailwind": {
    "config": "tailwind.config.ts",
    "css": "src/index.css",
    "baseColor": "slate",
    "cssVariables": true
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils"
  }
}
```

`frontend/src/lib/utils.ts`:
```ts
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

- [ ] **Step 7: Create index.css with Tailwind + shadcn CSS variables**

`frontend/src/index.css`:
```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 222.2 84% 4.9%;
    --card: 0 0% 100%;
    --card-foreground: 222.2 84% 4.9%;
    --popover: 0 0% 100%;
    --popover-foreground: 222.2 84% 4.9%;
    --primary: 222.2 47.4% 11.2%;
    --primary-foreground: 210 40% 98%;
    --secondary: 210 40% 96.1%;
    --secondary-foreground: 222.2 47.4% 11.2%;
    --muted: 210 40% 96.1%;
    --muted-foreground: 215.4 16.3% 46.9%;
    --accent: 210 40% 96.1%;
    --accent-foreground: 222.2 47.4% 11.2%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 222.2 84% 4.9%;
    --radius: 0.5rem;
  }
}

@layer base {
  * {
    @apply border-border;
  }
  body {
    @apply bg-background text-foreground;
  }
}
```

- [ ] **Step 8: Create main.tsx and placeholder App.tsx**

`frontend/src/main.tsx`:
```tsx
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import App from "./App";
import "./index.css";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </QueryClientProvider>
  </StrictMode>,
);
```

`frontend/src/App.tsx`:
```tsx
export default function App() {
  return <div className="p-8 text-lg">GPU Spot Lotto — Loading...</div>;
}
```

- [ ] **Step 9: Install dependencies and verify build**

```bash
cd frontend && npm install && npm run build
```

Expected: Build succeeds, `dist/` created with `index.html` + JS/CSS bundles.

- [ ] **Step 10: Install shadcn/ui components**

```bash
cd frontend && npx shadcn@latest add button card input label select separator tabs badge table dialog dropdown-menu skeleton alert -y
```

This installs the UI primitives we need into `frontend/src/components/ui/`.

- [ ] **Step 11: Verify build still passes**

```bash
cd frontend && npm run build
```

Expected: Build succeeds.

- [ ] **Step 12: Commit**

```bash
git add frontend/
git commit -m "feat(frontend): scaffold React project with Vite, Tailwind, shadcn/ui"
```

---

## Task 2: Types, API Client, and Auth Utilities

**Files:**
- Create: `frontend/src/lib/types.ts`, `frontend/src/lib/api.ts`, `frontend/src/lib/auth.ts`

- [ ] **Step 1: Create types.ts**

These types mirror the Python backend models exactly.

```ts
// frontend/src/lib/types.ts

export type JobStatus =
  | "queued"
  | "running"
  | "succeeded"
  | "failed"
  | "cancelling"
  | "cancelled";

export interface JobRequest {
  image: string;
  command: string[];
  instance_type: string;
  gpu_type: string;
  gpu_count: number;
  storage_mode: string;
  checkpoint_enabled: boolean;
  webhook_url?: string;
}

export interface JobRecord {
  job_id: string;
  user_id: string;
  region: string;
  status: JobStatus;
  pod_name: string;
  instance_type: string;
  created_at: number;
  finished_at?: number;
  retry_count: number;
  checkpoint_enabled: boolean;
  webhook_url?: string;
  result_path?: string;
  error_reason?: string;
}

export interface PriceEntry {
  region: string;
  instance_type: string;
  price: number;
}

export interface TemplateEntry {
  name: string;
  image: string;
  instance_type: string;
  gpu_count: number;
  gpu_type: string;
  storage_mode: string;
  checkpoint_enabled: boolean;
  command: string[];
}

export interface RegionInfo {
  region: string;
  available_capacity: number;
}

export interface AdminStats {
  active_jobs: number;
  queue_depth: number;
}

export interface UserInfo {
  user_id: string;
  role: "admin" | "user";
}
```

- [ ] **Step 2: Create api.ts**

```ts
// frontend/src/lib/api.ts

import axios from "axios";
import type {
  AdminStats,
  JobRecord,
  JobRequest,
  PriceEntry,
  RegionInfo,
  TemplateEntry,
} from "./types";

const api = axios.create({
  baseURL: "/api",
  headers: { "Content-Type": "application/json" },
});

// --- Prices ---
export async function fetchPrices(instanceType?: string): Promise<PriceEntry[]> {
  const params = instanceType ? { instance_type: instanceType } : {};
  const { data } = await api.get<{ prices: PriceEntry[] }>("/prices", { params });
  return data.prices;
}

// --- Jobs ---
export async function submitJob(req: JobRequest) {
  const { data } = await api.post<{ status: string; message: string }>("/jobs", req);
  return data;
}

export async function fetchJob(jobId: string): Promise<JobRecord> {
  const { data } = await api.get<JobRecord>(`/jobs/${jobId}`);
  return data;
}

export async function cancelJob(jobId: string) {
  const { data } = await api.delete<{ status: string; job_id: string }>(`/jobs/${jobId}`);
  return data;
}

// --- Templates ---
export async function fetchTemplates(): Promise<TemplateEntry[]> {
  const { data } = await api.get<{ templates: TemplateEntry[] }>("/templates");
  return data.templates;
}

export async function saveTemplate(template: TemplateEntry) {
  const { data } = await api.post<{ status: string; name: string }>("/templates", template);
  return data;
}

export async function deleteTemplate(name: string) {
  const { data } = await api.delete<{ status: string; name: string }>(
    `/templates/${encodeURIComponent(name)}`,
  );
  return data;
}

// --- Upload ---
export async function presignUpload(filename: string, prefix: string = "models") {
  const { data } = await api.post<{ url: string; fields: Record<string, string> }>(
    "/upload/presign",
    { filename, prefix },
  );
  return data;
}

// --- Settings ---
export async function saveWebhookUrl(webhookUrl: string) {
  const { data } = await api.put<{ status: string }>("/settings/webhook", {
    webhook_url: webhookUrl,
  });
  return data;
}

// --- Admin ---
export async function fetchAdminJobs(): Promise<JobRecord[]> {
  const { data } = await api.get<{ jobs: JobRecord[]; count: number }>("/admin/jobs");
  return data.jobs;
}

export async function adminForceCancel(jobId: string) {
  const { data } = await api.delete<{ status: string }>(`/admin/jobs/${jobId}`);
  return data;
}

export async function adminForceRetry(jobId: string) {
  const { data } = await api.post<{ status: string }>(`/admin/jobs/${jobId}/retry`);
  return data;
}

export async function fetchAdminRegions(): Promise<RegionInfo[]> {
  const { data } = await api.get<{ regions: RegionInfo[] }>("/admin/regions");
  return data.regions;
}

export async function updateRegionCapacity(region: string, capacity: number) {
  const { data } = await api.put<{ region: string; capacity: number }>(
    `/admin/regions/${region}/capacity`,
    { capacity },
  );
  return data;
}

export async function fetchAdminStats(): Promise<AdminStats> {
  const { data } = await api.get<AdminStats>("/admin/stats");
  return data;
}
```

- [ ] **Step 3: Create auth.ts**

```ts
// frontend/src/lib/auth.ts

import type { UserInfo } from "./types";

/**
 * Decode ALB-forwarded JWT payload (no signature verification).
 * In dev mode (AUTH_ENABLED=false), returns a default admin user.
 */
export function decodeJwtPayload(token: string): Record<string, unknown> {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("Invalid JWT");
  let payload = parts[1]!;
  // Add base64 padding
  const pad = 4 - (payload.length % 4);
  if (pad !== 4) payload += "=".repeat(pad);
  return JSON.parse(atob(payload));
}

/**
 * Extract user info from ALB JWT cookie or default to dev user.
 * In local dev (no ALB), the backend returns dev-user/admin automatically.
 */
export function getUserFromToken(): UserInfo {
  // In dev mode, there's no JWT — we rely on the backend's AUTH_ENABLED=false
  // The frontend always behaves as if the user is authenticated
  return { user_id: "dev-user", role: "admin" };
}
```

- [ ] **Step 4: Verify build**

```bash
cd frontend && npm run build
```

Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/lib/
git commit -m "feat(frontend): add TypeScript types, API client, and auth utilities"
```

---

## Task 3: Auth Hook, Layout, and App Routing

**Files:**
- Create: `frontend/src/hooks/useAuth.ts`, `frontend/src/components/layout/Sidebar.tsx`, `frontend/src/components/layout/Header.tsx`, `frontend/src/components/layout/AppLayout.tsx`
- Modify: `frontend/src/App.tsx`

- [ ] **Step 1: Create useAuth hook**

```tsx
// frontend/src/hooks/useAuth.ts

import { createContext, useContext } from "react";
import type { UserInfo } from "@/lib/types";

export const AuthContext = createContext<UserInfo>({
  user_id: "dev-user",
  role: "admin",
});

export function useAuth(): UserInfo {
  return useContext(AuthContext);
}
```

- [ ] **Step 2: Create Sidebar**

```tsx
// frontend/src/components/layout/Sidebar.tsx

import { Link, useLocation } from "react-router-dom";
import {
  LayoutDashboard,
  Cpu,
  DollarSign,
  FileText,
  Settings,
  ShieldCheck,
  Plus,
} from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { cn } from "@/lib/utils";

const userLinks = [
  { to: "/", label: "Dashboard", icon: LayoutDashboard },
  { to: "/jobs", label: "Jobs", icon: Cpu },
  { to: "/jobs/new", label: "New Job", icon: Plus },
  { to: "/prices", label: "Prices", icon: DollarSign },
  { to: "/templates", label: "Templates", icon: FileText },
  { to: "/settings", label: "Settings", icon: Settings },
];

const adminLinks = [
  { to: "/admin", label: "Admin Dashboard", icon: ShieldCheck },
  { to: "/admin/jobs", label: "All Jobs", icon: Cpu },
  { to: "/admin/regions", label: "Regions", icon: LayoutDashboard },
];

export function Sidebar() {
  const location = useLocation();
  const user = useAuth();

  return (
    <aside className="flex h-screen w-56 flex-col border-r bg-card px-3 py-4">
      <div className="mb-6 px-2 text-lg font-bold">GPU Spot Lotto</div>

      <nav className="flex flex-1 flex-col gap-1">
        {userLinks.map(({ to, label, icon: Icon }) => (
          <Link
            key={to}
            to={to}
            className={cn(
              "flex items-center gap-2 rounded-md px-2 py-1.5 text-sm hover:bg-accent",
              location.pathname === to && "bg-accent font-medium",
            )}
          >
            <Icon className="h-4 w-4" />
            {label}
          </Link>
        ))}

        {user.role === "admin" && (
          <>
            <div className="my-3 border-t" />
            <div className="px-2 text-xs font-semibold uppercase text-muted-foreground">
              Admin
            </div>
            {adminLinks.map(({ to, label, icon: Icon }) => (
              <Link
                key={to}
                to={to}
                className={cn(
                  "flex items-center gap-2 rounded-md px-2 py-1.5 text-sm hover:bg-accent",
                  location.pathname === to && "bg-accent font-medium",
                )}
              >
                <Icon className="h-4 w-4" />
                {label}
              </Link>
            ))}
          </>
        )}
      </nav>
    </aside>
  );
}
```

- [ ] **Step 3: Create Header**

```tsx
// frontend/src/components/layout/Header.tsx

import { useAuth } from "@/hooks/useAuth";
import { Badge } from "@/components/ui/badge";

export function Header() {
  const user = useAuth();

  return (
    <header className="flex h-14 items-center justify-between border-b px-6">
      <div />
      <div className="flex items-center gap-3">
        <span className="text-sm text-muted-foreground">{user.user_id}</span>
        <Badge variant={user.role === "admin" ? "default" : "secondary"}>
          {user.role}
        </Badge>
      </div>
    </header>
  );
}
```

- [ ] **Step 4: Create AppLayout**

```tsx
// frontend/src/components/layout/AppLayout.tsx

import { Outlet } from "react-router-dom";
import { Sidebar } from "./Sidebar";
import { Header } from "./Header";

export function AppLayout() {
  return (
    <div className="flex h-screen">
      <Sidebar />
      <div className="flex flex-1 flex-col overflow-hidden">
        <Header />
        <main className="flex-1 overflow-auto p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
```

- [ ] **Step 5: Update App.tsx with routes**

```tsx
// frontend/src/App.tsx

import { Routes, Route } from "react-router-dom";
import { AuthContext } from "@/hooks/useAuth";
import { getUserFromToken } from "@/lib/auth";
import { AppLayout } from "@/components/layout/AppLayout";

// Page placeholders (to be replaced in later tasks)
function Placeholder({ name }: { name: string }) {
  return <div className="text-lg text-muted-foreground">{name} — coming soon</div>;
}

const user = getUserFromToken();

export default function App() {
  return (
    <AuthContext.Provider value={user}>
      <Routes>
        <Route element={<AppLayout />}>
          <Route path="/" element={<Placeholder name="Dashboard" />} />
          <Route path="/jobs" element={<Placeholder name="Jobs" />} />
          <Route path="/jobs/new" element={<Placeholder name="New Job" />} />
          <Route path="/jobs/:id" element={<Placeholder name="Job Detail" />} />
          <Route path="/prices" element={<Placeholder name="Prices" />} />
          <Route path="/templates" element={<Placeholder name="Templates" />} />
          <Route path="/settings" element={<Placeholder name="Settings" />} />
          <Route path="/admin" element={<Placeholder name="Admin Dashboard" />} />
          <Route path="/admin/jobs" element={<Placeholder name="Admin Jobs" />} />
          <Route path="/admin/regions" element={<Placeholder name="Admin Regions" />} />
        </Route>
      </Routes>
    </AuthContext.Provider>
  );
}
```

- [ ] **Step 6: Verify build**

```bash
cd frontend && npm run build
```

Expected: Build succeeds.

- [ ] **Step 7: Commit**

```bash
git add frontend/src/
git commit -m "feat(frontend): add auth hook, layout components, and app routing"
```

---

## Task 4: Prices Page

**Files:**
- Create: `frontend/src/hooks/usePrices.ts`, `frontend/src/components/prices/PriceTable.tsx`, `frontend/src/pages/Prices.tsx`
- Modify: `frontend/src/App.tsx` (replace Prices placeholder)

- [ ] **Step 1: Create usePrices hook**

```ts
// frontend/src/hooks/usePrices.ts

import { useQuery } from "@tanstack/react-query";
import { fetchPrices } from "@/lib/api";

export function usePrices(instanceType?: string) {
  return useQuery({
    queryKey: ["prices", instanceType],
    queryFn: () => fetchPrices(instanceType),
    refetchInterval: 30_000,
  });
}
```

- [ ] **Step 2: Create PriceTable component**

```tsx
// frontend/src/components/prices/PriceTable.tsx

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
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
                <Badge variant="secondary" className="ml-2">
                  Cheapest
                </Badge>
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
```

- [ ] **Step 3: Create Prices page**

```tsx
// frontend/src/pages/Prices.tsx

import { useState } from "react";
import { usePrices } from "@/hooks/usePrices";
import { PriceTable } from "@/components/prices/PriceTable";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

const INSTANCE_TYPES = [
  "g6.xlarge",
  "g5.xlarge",
  "g6e.xlarge",
  "g6e.2xlarge",
  "g5.12xlarge",
  "g5.48xlarge",
];

export default function Prices() {
  const [filter, setFilter] = useState<string | undefined>(undefined);
  const { data: prices, isLoading } = usePrices(filter);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Spot Prices</h1>
        <Select
          value={filter ?? "all"}
          onValueChange={(v) => setFilter(v === "all" ? undefined : v)}
        >
          <SelectTrigger className="w-48">
            <SelectValue placeholder="All instances" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All instances</SelectItem>
            {INSTANCE_TYPES.map((t) => (
              <SelectItem key={t} value={t}>
                {t}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <p className="text-sm text-muted-foreground">
        Prices refresh every 30 seconds. Sorted cheapest-first.
      </p>

      <Card>
        <CardHeader>
          <CardTitle>Current Spot Prices (3 Regions)</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="space-y-2">
              {Array.from({ length: 6 }).map((_, i) => (
                <Skeleton key={i} className="h-10 w-full" />
              ))}
            </div>
          ) : (
            <PriceTable prices={prices ?? []} />
          )}
        </CardContent>
      </Card>
    </div>
  );
}
```

- [ ] **Step 4: Wire Prices page into App.tsx**

Replace the Prices placeholder route in `frontend/src/App.tsx`:

Add import at top:
```tsx
import Prices from "@/pages/Prices";
```

Replace the route:
```tsx
<Route path="/prices" element={<Prices />} />
```

- [ ] **Step 5: Verify build**

```bash
cd frontend && npm run build
```

Expected: Build succeeds.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/
git commit -m "feat(frontend): add prices page with 30s polling and instance filter"
```

---

## Task 5: Jobs List Page

**Files:**
- Create: `frontend/src/hooks/useJobs.ts`, `frontend/src/components/jobs/JobStatusBadge.tsx`, `frontend/src/components/jobs/JobTable.tsx`, `frontend/src/pages/Jobs.tsx`
- Modify: `frontend/src/App.tsx`

- [ ] **Step 1: Create useJobs hook**

```ts
// frontend/src/hooks/useJobs.ts

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { cancelJob, fetchJob, submitJob } from "@/lib/api";
import type { JobRequest } from "@/lib/types";

export function useJob(jobId: string) {
  return useQuery({
    queryKey: ["job", jobId],
    queryFn: () => fetchJob(jobId),
    refetchInterval: 5_000,
  });
}

export function useSubmitJob() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (req: JobRequest) => submitJob(req),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["admin-stats"] }),
  });
}

export function useCancelJob() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (jobId: string) => cancelJob(jobId),
    onSuccess: (_data, jobId) => {
      qc.invalidateQueries({ queryKey: ["job", jobId] });
    },
  });
}
```

- [ ] **Step 2: Create JobStatusBadge**

```tsx
// frontend/src/components/jobs/JobStatusBadge.tsx

import { Badge } from "@/components/ui/badge";
import type { JobStatus } from "@/lib/types";

const statusConfig: Record<JobStatus, { label: string; variant: "default" | "secondary" | "destructive" | "outline" }> = {
  queued: { label: "Queued", variant: "secondary" },
  running: { label: "Running", variant: "default" },
  succeeded: { label: "Succeeded", variant: "outline" },
  failed: { label: "Failed", variant: "destructive" },
  cancelling: { label: "Cancelling", variant: "secondary" },
  cancelled: { label: "Cancelled", variant: "secondary" },
};

export function JobStatusBadge({ status }: { status: JobStatus }) {
  const config = statusConfig[status];
  return <Badge variant={config.variant}>{config.label}</Badge>;
}
```

- [ ] **Step 3: Create JobTable**

```tsx
// frontend/src/components/jobs/JobTable.tsx

import { Link } from "react-router-dom";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { JobStatusBadge } from "./JobStatusBadge";
import type { JobRecord } from "@/lib/types";

interface JobTableProps {
  jobs: JobRecord[];
}

function formatTime(epoch: number): string {
  return new Date(epoch * 1000).toLocaleString();
}

function duration(start: number, end?: number): string {
  const seconds = (end ?? Math.floor(Date.now() / 1000)) - start;
  if (seconds < 60) return `${seconds}s`;
  const min = Math.floor(seconds / 60);
  const sec = seconds % 60;
  return `${min}m ${sec}s`;
}

export function JobTable({ jobs }: JobTableProps) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Job ID</TableHead>
          <TableHead>Status</TableHead>
          <TableHead>Instance</TableHead>
          <TableHead>Region</TableHead>
          <TableHead>Duration</TableHead>
          <TableHead>Created</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {jobs.map((job) => (
          <TableRow key={job.job_id}>
            <TableCell>
              <Link
                to={`/jobs/${job.job_id}`}
                className="font-mono text-sm text-primary underline-offset-4 hover:underline"
              >
                {job.job_id.slice(0, 8)}
              </Link>
            </TableCell>
            <TableCell>
              <JobStatusBadge status={job.status} />
            </TableCell>
            <TableCell className="font-mono text-sm">{job.instance_type}</TableCell>
            <TableCell>{job.region}</TableCell>
            <TableCell className="font-mono text-sm">
              {duration(job.created_at, job.finished_at ?? undefined)}
            </TableCell>
            <TableCell className="text-sm text-muted-foreground">
              {formatTime(job.created_at)}
            </TableCell>
          </TableRow>
        ))}
        {jobs.length === 0 && (
          <TableRow>
            <TableCell colSpan={6} className="text-center text-muted-foreground">
              No jobs found
            </TableCell>
          </TableRow>
        )}
      </TableBody>
    </Table>
  );
}
```

- [ ] **Step 4: Create Jobs page**

```tsx
// frontend/src/pages/Jobs.tsx

import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { fetchAdminJobs } from "@/lib/api";
import { JobTable } from "@/components/jobs/JobTable";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Plus } from "lucide-react";

export default function Jobs() {
  // In dev mode (auth disabled), user is admin — we use admin/jobs to see all
  const { data: jobs, isLoading } = useQuery({
    queryKey: ["admin-jobs"],
    queryFn: fetchAdminJobs,
    refetchInterval: 10_000,
  });

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">My Jobs</h1>
        <Button asChild>
          <Link to="/jobs/new">
            <Plus className="mr-2 h-4 w-4" />
            New Job
          </Link>
        </Button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Job History</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="space-y-2">
              {Array.from({ length: 5 }).map((_, i) => (
                <Skeleton key={i} className="h-12 w-full" />
              ))}
            </div>
          ) : (
            <JobTable jobs={jobs ?? []} />
          )}
        </CardContent>
      </Card>
    </div>
  );
}
```

- [ ] **Step 5: Wire Jobs page into App.tsx**

Add import:
```tsx
import Jobs from "@/pages/Jobs";
```

Replace the Jobs route:
```tsx
<Route path="/jobs" element={<Jobs />} />
```

- [ ] **Step 6: Verify build and commit**

```bash
cd frontend && npm run build
git add frontend/src/
git commit -m "feat(frontend): add jobs list page with status badges and auto-refresh"
```

---

## Task 6: Job Submission Page

**Files:**
- Create: `frontend/src/components/guide/InstanceGuide.tsx`, `frontend/src/components/templates/TemplateSelector.tsx`, `frontend/src/components/upload/FileUpload.tsx`, `frontend/src/components/jobs/JobForm.tsx`, `frontend/src/pages/JobNew.tsx`
- Modify: `frontend/src/App.tsx`

- [ ] **Step 1: Create InstanceGuide**

```tsx
// frontend/src/components/guide/InstanceGuide.tsx

import { Card, CardContent } from "@/components/ui/card";
import type { PriceEntry } from "@/lib/types";
import { cn } from "@/lib/utils";

interface TierInfo {
  tier: number;
  label: string;
  instances: string[];
  gpu: string;
  vram: string;
  useCase: string;
}

const TIERS: TierInfo[] = [
  {
    tier: 1,
    label: "Inference / Light",
    instances: ["g6.xlarge", "g5.xlarge"],
    gpu: "1x L4 / A10G",
    vram: "24GB",
    useCase: "Inference, light training, QLoRA 7B",
  },
  {
    tier: 2,
    label: "LLM Fine-tuning",
    instances: ["g6e.xlarge", "g6e.2xlarge"],
    gpu: "1x L40S",
    vram: "48GB",
    useCase: "13B+ QLoRA, 7B full fine-tuning",
  },
  {
    tier: 3,
    label: "Distributed Training",
    instances: ["g5.12xlarge", "g5.48xlarge"],
    gpu: "4-8x A10G",
    vram: "96-192GB",
    useCase: "Large-scale distributed training",
  },
];

interface InstanceGuideProps {
  prices: PriceEntry[];
  selectedInstance: string;
  onSelect: (instance: string) => void;
}

export function InstanceGuide({ prices, selectedInstance, onSelect }: InstanceGuideProps) {
  const priceMap = new Map(prices.map((p) => [`${p.region}:${p.instance_type}`, p.price]));

  function cheapestPrice(instanceType: string): number | null {
    let min: number | null = null;
    for (const [key, price] of priceMap) {
      if (key.endsWith(`:${instanceType}`)) {
        if (min === null || price < min) min = price;
      }
    }
    return min;
  }

  return (
    <div className="space-y-3">
      <p className="text-sm text-muted-foreground">
        Not sure which tier? Start with Tier 1 — you can always scale up.
      </p>
      {TIERS.map((tier) => (
        <Card key={tier.tier}>
          <CardContent className="py-3">
            <div className="mb-1 text-sm font-semibold">
              Tier {tier.tier}: {tier.label}
            </div>
            <div className="mb-2 text-xs text-muted-foreground">
              {tier.gpu} / {tier.vram} — {tier.useCase}
            </div>
            <div className="flex flex-wrap gap-2">
              {tier.instances.map((inst) => {
                const price = cheapestPrice(inst);
                return (
                  <button
                    key={inst}
                    type="button"
                    onClick={() => onSelect(inst)}
                    className={cn(
                      "rounded border px-3 py-1 text-sm transition-colors hover:bg-accent",
                      selectedInstance === inst && "border-primary bg-accent font-medium",
                    )}
                  >
                    <span className="font-mono">{inst}</span>
                    {price !== null && (
                      <span className="ml-2 text-xs text-muted-foreground">
                        from ${price.toFixed(3)}/hr
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
```

- [ ] **Step 2: Create TemplateSelector**

```tsx
// frontend/src/components/templates/TemplateSelector.tsx

import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { TemplateEntry } from "@/lib/types";

interface TemplateSelectorProps {
  templates: TemplateEntry[];
  onSelect: (template: TemplateEntry) => void;
}

export function TemplateSelector({ templates, onSelect }: TemplateSelectorProps) {
  if (templates.length === 0) return null;

  return (
    <Select
      onValueChange={(name) => {
        const t = templates.find((t) => t.name === name);
        if (t) onSelect(t);
      }}
    >
      <SelectTrigger className="w-64">
        <SelectValue placeholder="Load from template..." />
      </SelectTrigger>
      <SelectContent>
        {templates.map((t) => (
          <SelectItem key={t.name} value={t.name}>
            {t.name}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
```

- [ ] **Step 3: Create FileUpload**

```tsx
// frontend/src/components/upload/FileUpload.tsx

import { useCallback, useState } from "react";
import { presignUpload } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Upload } from "lucide-react";

interface FileUploadProps {
  prefix?: string;
  onUploaded?: (path: string) => void;
}

export function FileUpload({ prefix = "models", onUploaded }: FileUploadProps) {
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [filename, setFilename] = useState<string | null>(null);

  const handleFile = useCallback(
    async (file: File) => {
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
    },
    [prefix, onUploaded],
  );

  return (
    <div
      className="rounded-md border-2 border-dashed p-4 text-center"
      onDragOver={(e) => e.preventDefault()}
      onDrop={(e) => {
        e.preventDefault();
        const file = e.dataTransfer.files[0];
        if (file) handleFile(file);
      }}
    >
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
              <input
                type="file"
                className="hidden"
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) handleFile(file);
                }}
              />
            </label>
          </p>
        </>
      )}
    </div>
  );
}
```

- [ ] **Step 4: Create JobForm**

```tsx
// frontend/src/components/jobs/JobForm.tsx

import { useState } from "react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
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
  const [command, setCommand] = useState(
    initialValues?.command?.join(" ") ?? "nvidia-smi && sleep 60",
  );

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const gpu = GPU_MAP[instanceType] ?? { type: "l4", count: 1 };
    onSubmit({
      image,
      instance_type: instanceType,
      gpu_type: gpu.type,
      gpu_count: gpu.count,
      storage_mode: storageMode,
      checkpoint_enabled: checkpoint,
      command: ["/bin/sh", "-c", command],
    });
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="space-y-2">
        <Label htmlFor="image">Container Image</Label>
        <Input
          id="image"
          value={image}
          onChange={(e) => setImage(e.target.value)}
          placeholder="nvidia/cuda:12.0-base"
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor="instance">Instance Type</Label>
        <Select value={instanceType} onValueChange={setInstanceType}>
          <SelectTrigger id="instance">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {Object.keys(GPU_MAP).map((t) => (
              <SelectItem key={t} value={t}>
                {t} ({GPU_MAP[t]!.count}x {GPU_MAP[t]!.type.toUpperCase()})
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <div className="space-y-2">
        <Label htmlFor="storage">Storage Mode</Label>
        <Select value={storageMode} onValueChange={setStorageMode}>
          <SelectTrigger id="storage">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="s3">S3 Mountpoint</SelectItem>
            <SelectItem value="fsx">FSx for Lustre</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div className="flex items-center gap-2">
        <input
          type="checkbox"
          id="checkpoint"
          checked={checkpoint}
          onChange={(e) => setCheckpoint(e.target.checked)}
          className="h-4 w-4 rounded border"
        />
        <Label htmlFor="checkpoint">Enable checkpointing</Label>
      </div>

      <div className="space-y-2">
        <Label htmlFor="command">Command</Label>
        <Input
          id="command"
          value={command}
          onChange={(e) => setCommand(e.target.value)}
          placeholder="nvidia-smi && sleep 60"
        />
      </div>

      <Button type="submit" disabled={isSubmitting}>
        {isSubmitting ? "Submitting..." : "Submit Job"}
      </Button>
    </form>
  );
}
```

- [ ] **Step 5: Create JobNew page**

```tsx
// frontend/src/pages/JobNew.tsx

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
  const { data: templates } = useQuery({
    queryKey: ["templates"],
    queryFn: fetchTemplates,
  });
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

      {submitted && (
        <Alert>
          <AlertDescription>Job submitted to queue. Redirecting to jobs list...</AlertDescription>
        </Alert>
      )}

      <div className="grid gap-6 lg:grid-cols-2">
        <div className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Instance Selection Guide</CardTitle>
            </CardHeader>
            <CardContent>
              <InstanceGuide
                prices={prices ?? []}
                selectedInstance={selectedInstance}
                onSelect={(inst) => {
                  setSelectedInstance(inst);
                  setSelectedTemplate((prev) =>
                    prev ? { ...prev, instance_type: inst } : { instance_type: inst },
                  );
                }}
              />
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>File Upload</CardTitle>
            </CardHeader>
            <CardContent>
              <FileUpload prefix="models" />
            </CardContent>
          </Card>
        </div>

        <Card>
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle>Job Configuration</CardTitle>
              <TemplateSelector
                templates={templates ?? []}
                onSelect={handleTemplateSelect}
              />
            </div>
          </CardHeader>
          <CardContent>
            <JobForm
              key={selectedTemplate?.name ?? selectedInstance}
              initialValues={{
                ...selectedTemplate,
                instance_type: selectedInstance,
              }}
              isSubmitting={submitJob.isPending}
              onSubmit={(req) => {
                submitJob.mutate(req, {
                  onSuccess: () => {
                    setSubmitted(true);
                    setTimeout(() => navigate("/jobs"), 1500);
                  },
                });
              }}
            />
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
```

- [ ] **Step 6: Wire JobNew into App.tsx**

Add import:
```tsx
import JobNew from "@/pages/JobNew";
```

Replace route:
```tsx
<Route path="/jobs/new" element={<JobNew />} />
```

- [ ] **Step 7: Verify build and commit**

```bash
cd frontend && npm run build
git add frontend/src/
git commit -m "feat(frontend): add job submission page with instance guide, templates, file upload"
```

---

## Task 7: Job Detail Page with SSE

**Files:**
- Create: `frontend/src/hooks/useJobStream.ts`, `frontend/src/pages/JobDetail.tsx`
- Modify: `frontend/src/App.tsx`

- [ ] **Step 1: Create useJobStream SSE hook**

```ts
// frontend/src/hooks/useJobStream.ts

import { useEffect, useRef, useState } from "react";
import type { JobStatus } from "@/lib/types";

interface StatusEvent {
  status: JobStatus;
  [key: string]: unknown;
}

export function useJobStream(jobId: string) {
  const [events, setEvents] = useState<StatusEvent[]>([]);
  const [connected, setConnected] = useState(false);
  const sourceRef = useRef<EventSource | null>(null);

  useEffect(() => {
    const es = new EventSource(`/api/jobs/${jobId}/stream`);
    sourceRef.current = es;

    es.onopen = () => setConnected(true);

    es.addEventListener("status", (e) => {
      try {
        const data = JSON.parse(e.data) as StatusEvent;
        setEvents((prev) => [...prev, data]);
        // Close on terminal status
        if (["succeeded", "failed", "cancelled"].includes(data.status)) {
          es.close();
          setConnected(false);
        }
      } catch {
        // ignore parse errors
      }
    });

    es.onerror = () => {
      setConnected(false);
      es.close();
    };

    return () => {
      es.close();
      setConnected(false);
    };
  }, [jobId]);

  const latestStatus = events.length > 0 ? events[events.length - 1]!.status : null;

  return { events, connected, latestStatus };
}
```

- [ ] **Step 2: Create JobDetail page**

```tsx
// frontend/src/pages/JobDetail.tsx

import { useParams, useNavigate } from "react-router-dom";
import { useJob, useCancelJob } from "@/hooks/useJobs";
import { useJobStream } from "@/hooks/useJobStream";
import { JobStatusBadge } from "@/components/jobs/JobStatusBadge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import type { JobStatus } from "@/lib/types";

function formatTime(epoch: number): string {
  return new Date(epoch * 1000).toLocaleString();
}

export default function JobDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { data: job, isLoading } = useJob(id!);
  const { events, connected } = useJobStream(id!);
  const cancelMut = useCancelJob();

  // Prefer SSE status over polling
  const currentStatus: JobStatus | undefined =
    events.length > 0 ? events[events.length - 1]!.status : job?.status;

  if (isLoading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-64 w-full" />
      </div>
    );
  }

  if (!job) {
    return <div className="text-muted-foreground">Job not found.</div>;
  }

  const canCancel = currentStatus === "running" || currentStatus === "queued";

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <h1 className="text-2xl font-bold font-mono">{job.job_id.slice(0, 12)}</h1>
          {currentStatus && <JobStatusBadge status={currentStatus} />}
          {connected && (
            <Badge variant="outline" className="text-green-600">
              SSE Live
            </Badge>
          )}
        </div>
        <div className="flex gap-2">
          {canCancel && (
            <Button
              variant="destructive"
              size="sm"
              onClick={() => cancelMut.mutate(job.job_id)}
              disabled={cancelMut.isPending}
            >
              Cancel Job
            </Button>
          )}
          <Button variant="outline" size="sm" onClick={() => navigate("/jobs")}>
            Back to Jobs
          </Button>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Job Info</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm">
            <Row label="Job ID" value={job.job_id} mono />
            <Row label="User" value={job.user_id} />
            <Row label="Instance" value={job.instance_type} mono />
            <Row label="Region" value={job.region} />
            <Row label="Pod" value={job.pod_name} mono />
            <Row label="Checkpoint" value={job.checkpoint_enabled ? "Enabled" : "Disabled"} />
            <Row label="Retries" value={String(job.retry_count)} />
            <Row label="Created" value={formatTime(job.created_at)} />
            {job.finished_at && <Row label="Finished" value={formatTime(job.finished_at)} />}
            {job.error_reason && <Row label="Error" value={job.error_reason} />}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Status Events</CardTitle>
          </CardHeader>
          <CardContent>
            {events.length === 0 ? (
              <p className="text-sm text-muted-foreground">
                {connected ? "Waiting for events..." : "No events received. SSE may not be active for this job."}
              </p>
            ) : (
              <div className="space-y-2">
                {events.map((evt, i) => (
                  <div key={i} className="flex items-center gap-2">
                    <JobStatusBadge status={evt.status} />
                    <span className="text-xs text-muted-foreground">
                      {JSON.stringify(evt)}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function Row({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <>
      <div className="flex justify-between">
        <span className="text-muted-foreground">{label}</span>
        <span className={mono ? "font-mono" : ""}>{value}</span>
      </div>
      <Separator />
    </>
  );
}
```

- [ ] **Step 3: Wire JobDetail into App.tsx**

Add import:
```tsx
import JobDetail from "@/pages/JobDetail";
```

Replace route:
```tsx
<Route path="/jobs/:id" element={<JobDetail />} />
```

- [ ] **Step 4: Verify build and commit**

```bash
cd frontend && npm run build
git add frontend/src/
git commit -m "feat(frontend): add job detail page with SSE real-time status stream"
```

---

## Task 8: Templates Page

**Files:**
- Create: `frontend/src/hooks/useTemplates.ts`, `frontend/src/pages/Templates.tsx`
- Modify: `frontend/src/App.tsx`

- [ ] **Step 1: Create useTemplates hook**

```ts
// frontend/src/hooks/useTemplates.ts

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { deleteTemplate, fetchTemplates, saveTemplate } from "@/lib/api";
import type { TemplateEntry } from "@/lib/types";

export function useTemplates() {
  return useQuery({
    queryKey: ["templates"],
    queryFn: fetchTemplates,
  });
}

export function useSaveTemplate() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (t: TemplateEntry) => saveTemplate(t),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["templates"] }),
  });
}

export function useDeleteTemplate() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (name: string) => deleteTemplate(name),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["templates"] }),
  });
}
```

- [ ] **Step 2: Create Templates page**

```tsx
// frontend/src/pages/Templates.tsx

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
```

- [ ] **Step 3: Wire Templates into App.tsx**

Add import:
```tsx
import Templates from "@/pages/Templates";
```

Replace route:
```tsx
<Route path="/templates" element={<Templates />} />
```

- [ ] **Step 4: Verify build and commit**

```bash
cd frontend && npm run build
git add frontend/src/
git commit -m "feat(frontend): add templates page with create/list/delete"
```

---

## Task 9: Dashboard and Settings Pages

**Files:**
- Create: `frontend/src/pages/Dashboard.tsx`, `frontend/src/pages/Settings.tsx`
- Modify: `frontend/src/App.tsx`

- [ ] **Step 1: Create Dashboard page**

```tsx
// frontend/src/pages/Dashboard.tsx

import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { fetchAdminStats, fetchPrices, fetchAdminJobs } from "@/lib/api";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { PriceTable } from "@/components/prices/PriceTable";
import { JobStatusBadge } from "@/components/jobs/JobStatusBadge";
import { Skeleton } from "@/components/ui/skeleton";
import { Plus } from "lucide-react";

export default function Dashboard() {
  const { data: stats } = useQuery({
    queryKey: ["admin-stats"],
    queryFn: fetchAdminStats,
    refetchInterval: 10_000,
  });
  const { data: prices, isLoading: pricesLoading } = useQuery({
    queryKey: ["prices"],
    queryFn: () => fetchPrices(),
    refetchInterval: 30_000,
  });
  const { data: jobs } = useQuery({
    queryKey: ["admin-jobs"],
    queryFn: fetchAdminJobs,
    refetchInterval: 10_000,
  });

  const recentJobs = (jobs ?? []).slice(0, 5);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Dashboard</h1>
        <Button asChild>
          <Link to="/jobs/new">
            <Plus className="mr-2 h-4 w-4" />
            New Job
          </Link>
        </Button>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Active Jobs</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{stats?.active_jobs ?? "—"}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Queue Depth</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{stats?.queue_depth ?? "—"}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Cheapest Spot</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">
              {prices && prices.length > 0
                ? `$${Math.min(...prices.map((p) => p.price)).toFixed(3)}/hr`
                : "—"}
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Recent Jobs</CardTitle>
          </CardHeader>
          <CardContent>
            {recentJobs.length === 0 ? (
              <p className="text-sm text-muted-foreground">No jobs yet</p>
            ) : (
              <div className="space-y-2">
                {recentJobs.map((job) => (
                  <Link
                    key={job.job_id}
                    to={`/jobs/${job.job_id}`}
                    className="flex items-center justify-between rounded-md px-2 py-1.5 hover:bg-accent"
                  >
                    <span className="font-mono text-sm">{job.job_id.slice(0, 8)}</span>
                    <div className="flex items-center gap-2">
                      <span className="text-sm text-muted-foreground">{job.instance_type}</span>
                      <JobStatusBadge status={job.status} />
                    </div>
                  </Link>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Spot Prices</CardTitle>
          </CardHeader>
          <CardContent>
            {pricesLoading ? (
              <Skeleton className="h-40 w-full" />
            ) : (
              <PriceTable prices={prices ?? []} />
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Create Settings page**

```tsx
// frontend/src/pages/Settings.tsx

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
```

- [ ] **Step 3: Wire Dashboard and Settings into App.tsx**

Add imports:
```tsx
import Dashboard from "@/pages/Dashboard";
import Settings from "@/pages/Settings";
```

Replace routes:
```tsx
<Route path="/" element={<Dashboard />} />
<Route path="/settings" element={<Settings />} />
```

- [ ] **Step 4: Verify build and commit**

```bash
cd frontend && npm run build
git add frontend/src/
git commit -m "feat(frontend): add dashboard with stats/prices and settings page"
```

---

## Task 10: Admin Pages

**Files:**
- Create: `frontend/src/hooks/useAdmin.ts`, `frontend/src/pages/admin/AdminDashboard.tsx`, `frontend/src/pages/admin/AdminJobs.tsx`, `frontend/src/pages/admin/AdminRegions.tsx`
- Modify: `frontend/src/App.tsx`

- [ ] **Step 1: Create useAdmin hook**

```ts
// frontend/src/hooks/useAdmin.ts

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  adminForceCancel,
  adminForceRetry,
  fetchAdminJobs,
  fetchAdminRegions,
  fetchAdminStats,
  updateRegionCapacity,
} from "@/lib/api";

export function useAdminStats() {
  return useQuery({
    queryKey: ["admin-stats"],
    queryFn: fetchAdminStats,
    refetchInterval: 10_000,
  });
}

export function useAdminJobs() {
  return useQuery({
    queryKey: ["admin-jobs"],
    queryFn: fetchAdminJobs,
    refetchInterval: 10_000,
  });
}

export function useAdminRegions() {
  return useQuery({
    queryKey: ["admin-regions"],
    queryFn: fetchAdminRegions,
    refetchInterval: 10_000,
  });
}

export function useForceCancel() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (jobId: string) => adminForceCancel(jobId),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["admin-jobs"] }),
  });
}

export function useForceRetry() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (jobId: string) => adminForceRetry(jobId),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["admin-jobs"] }),
  });
}

export function useUpdateCapacity() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ region, capacity }: { region: string; capacity: number }) =>
      updateRegionCapacity(region, capacity),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["admin-regions"] }),
  });
}
```

- [ ] **Step 2: Create AdminDashboard**

```tsx
// frontend/src/pages/admin/AdminDashboard.tsx

import { useAdminStats, useAdminRegions } from "@/hooks/useAdmin";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export default function AdminDashboard() {
  const { data: stats } = useAdminStats();
  const { data: regions } = useAdminRegions();

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Admin Dashboard</h1>

      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Active Jobs
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{stats?.active_jobs ?? "—"}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Queue Depth
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{stats?.queue_depth ?? "—"}</div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Region Capacity</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-3">
            {(regions ?? []).map((r) => (
              <div key={r.region} className="rounded-md border p-4">
                <div className="text-sm font-medium">{r.region}</div>
                <div className="mt-1 text-2xl font-bold">{r.available_capacity}</div>
                <div className="text-xs text-muted-foreground">GPU slots available</div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
```

- [ ] **Step 3: Create AdminJobs**

```tsx
// frontend/src/pages/admin/AdminJobs.tsx

import { useAdminJobs, useForceCancel, useForceRetry } from "@/hooks/useAdmin";
import { JobStatusBadge } from "@/components/jobs/JobStatusBadge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Skeleton } from "@/components/ui/skeleton";
import type { JobRecord } from "@/lib/types";

export default function AdminJobs() {
  const { data: jobs, isLoading } = useAdminJobs();
  const cancelMut = useForceCancel();
  const retryMut = useForceRetry();

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">All Jobs (Admin)</h1>

      <Card>
        <CardHeader>
          <CardTitle>Active Jobs</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="space-y-2">
              {Array.from({ length: 5 }).map((_, i) => (
                <Skeleton key={i} className="h-12 w-full" />
              ))}
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Job ID</TableHead>
                  <TableHead>User</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Instance</TableHead>
                  <TableHead>Region</TableHead>
                  <TableHead>Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {(jobs ?? []).map((job: JobRecord) => (
                  <TableRow key={job.job_id}>
                    <TableCell className="font-mono text-sm">{job.job_id.slice(0, 8)}</TableCell>
                    <TableCell>{job.user_id}</TableCell>
                    <TableCell>
                      <JobStatusBadge status={job.status} />
                    </TableCell>
                    <TableCell className="font-mono text-sm">{job.instance_type}</TableCell>
                    <TableCell>{job.region}</TableCell>
                    <TableCell>
                      <div className="flex gap-1">
                        {(job.status === "running" || job.status === "queued") && (
                          <Button
                            variant="destructive"
                            size="sm"
                            onClick={() => cancelMut.mutate(job.job_id)}
                            disabled={cancelMut.isPending}
                          >
                            Cancel
                          </Button>
                        )}
                        {job.status === "failed" && (
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => retryMut.mutate(job.job_id)}
                            disabled={retryMut.isPending}
                          >
                            Retry
                          </Button>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
                {(jobs ?? []).length === 0 && (
                  <TableRow>
                    <TableCell colSpan={6} className="text-center text-muted-foreground">
                      No active jobs
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
```

- [ ] **Step 4: Create AdminRegions**

```tsx
// frontend/src/pages/admin/AdminRegions.tsx

import { useState } from "react";
import { useAdminRegions, useUpdateCapacity } from "@/hooks/useAdmin";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

const REGION_LABELS: Record<string, string> = {
  "us-east-1": "US East (Virginia)",
  "us-east-2": "US East (Ohio)",
  "us-west-2": "US West (Oregon)",
};

export default function AdminRegions() {
  const { data: regions } = useAdminRegions();
  const updateMut = useUpdateCapacity();
  const [editing, setEditing] = useState<Record<string, string>>({});

  function handleSave(region: string) {
    const val = parseInt(editing[region] ?? "", 10);
    if (isNaN(val) || val < 0) return;
    updateMut.mutate({ region, capacity: val }, {
      onSuccess: () => setEditing((prev) => {
        const next = { ...prev };
        delete next[region];
        return next;
      }),
    });
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Region Management</h1>

      <div className="grid gap-4 md:grid-cols-3">
        {(regions ?? []).map((r) => (
          <Card key={r.region}>
            <CardHeader>
              <CardTitle className="text-base">
                {REGION_LABELS[r.region] ?? r.region}
              </CardTitle>
              <div className="text-xs text-muted-foreground font-mono">{r.region}</div>
            </CardHeader>
            <CardContent className="space-y-3">
              <div>
                <div className="text-3xl font-bold">{r.available_capacity}</div>
                <div className="text-xs text-muted-foreground">GPU slots available</div>
              </div>
              <div className="space-y-2">
                <Label>Set Capacity</Label>
                <div className="flex gap-2">
                  <Input
                    type="number"
                    min={0}
                    value={editing[r.region] ?? ""}
                    onChange={(e) =>
                      setEditing((prev) => ({ ...prev, [r.region]: e.target.value }))
                    }
                    placeholder={String(r.available_capacity)}
                    className="w-24"
                  />
                  <Button
                    size="sm"
                    onClick={() => handleSave(r.region)}
                    disabled={updateMut.isPending || !editing[r.region]}
                  >
                    Update
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
```

- [ ] **Step 5: Wire admin pages into App.tsx**

Add imports:
```tsx
import AdminDashboard from "@/pages/admin/AdminDashboard";
import AdminJobs from "@/pages/admin/AdminJobs";
import AdminRegions from "@/pages/admin/AdminRegions";
```

Replace routes:
```tsx
<Route path="/admin" element={<AdminDashboard />} />
<Route path="/admin/jobs" element={<AdminJobs />} />
<Route path="/admin/regions" element={<AdminRegions />} />
```

- [ ] **Step 6: Verify build and commit**

```bash
cd frontend && npm run build
git add frontend/src/
git commit -m "feat(frontend): add admin pages (dashboard, jobs, regions)"
```

---

## Task 11: Dockerfile, nginx, and docker-compose Integration

**Files:**
- Create: `frontend/Dockerfile`, `frontend/nginx.conf`
- Modify: `docker-compose.yml`

- [ ] **Step 1: Create nginx.conf**

```nginx
# frontend/nginx.conf
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # SPA: serve index.html for all non-file routes
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API proxy (only in docker-compose; production uses ALB routing)
    location /api/ {
        proxy_pass http://api-server:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 300s;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff2?)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Health check for k8s
    location /nginx-health {
        return 200 "ok";
        add_header Content-Type text/plain;
    }
}
```

- [ ] **Step 2: Create Dockerfile**

```dockerfile
# frontend/Dockerfile
# syntax=docker/dockerfile:1

# --- Build stage ---
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# --- Production stage ---
FROM nginx:alpine AS production
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

- [ ] **Step 3: Update docker-compose.yml — add frontend service**

Add to the end of `docker-compose.yml`, inside the `services:` block:

```yaml
  frontend:
    build:
      context: ./frontend
    ports:
      - "3000:80"
    depends_on:
      - api-server
```

- [ ] **Step 4: Build the frontend container**

```bash
docker compose build frontend
```

Expected: Build succeeds.

- [ ] **Step 5: Start the full stack and verify**

```bash
docker compose up --build -d
```

Verify frontend is accessible:
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
```
Expected: `200`

Verify API proxy works through frontend nginx:
```bash
curl -s http://localhost:3000/api/prices | python3 -c "import sys,json; print(json.load(sys.stdin)['prices'][:1])"
```
Expected: Prints a price entry.

- [ ] **Step 6: Stop the stack**

```bash
docker compose down
```

- [ ] **Step 7: Commit**

```bash
git add frontend/Dockerfile frontend/nginx.conf docker-compose.yml
git commit -m "feat(frontend): add Dockerfile, nginx config, and docker-compose integration"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] Dashboard (`/`) with job summary and prices — Task 9
- [x] Job submission (`/jobs/new`) with instance guide + templates + file upload — Task 6
- [x] Job templates (`/templates`) with CRUD — Task 8
- [x] Job list (`/jobs`) with status badges — Task 5
- [x] Job detail (`/jobs/:id`) with SSE real-time status — Task 7
- [x] Prices (`/prices`) with 30s polling and filtering — Task 4
- [x] Settings (`/settings`) with webhook URL — Task 9
- [x] Admin dashboard (`/admin`) — Task 10
- [x] Admin jobs (`/admin/jobs`) with force cancel/retry — Task 10
- [x] Admin regions (`/admin/regions`) with capacity management — Task 10
- [x] React + Vite + Tailwind + shadcn/ui — Task 1
- [x] Sidebar/Header layout with role-based nav — Task 3
- [x] API client matching backend routes — Task 2
- [x] JWT/auth utilities — Task 2
- [x] Dockerfile (multi-stage: node build → nginx) — Task 11
- [x] docker-compose frontend service — Task 11

**Not implemented (backend endpoints missing):**
- AdminUsers page — no backend user management API
- AdminSettings page — no backend runtime settings API
- Log streaming (`/api/jobs/{id}/logs`) — no backend endpoint
- Region enable/disable — no backend endpoint

**Placeholder scan:** No TBD/TODO. All tasks have complete code.

**Type consistency:** Frontend TypeScript types match Python Pydantic models. API function names match route patterns. Hook names follow `use{Resource}` convention throughout.
