# Frontend Module

## Role
React SPA dashboard for GPU Spot Lotto. Provides job management, price monitoring,
admin panel, and usage guide. Bilingual (Korean/English).

## Key Directories
- `src/pages/` -- Route pages (Dashboard, Jobs, JobNew, JobDetail, Prices, Guide, Agent, Settings, Templates)
- `src/components/ui/` -- shadcn/ui primitives (Button, Card, Table, Select, etc.)
- `src/components/jobs/` -- Job-specific components (JobTable, JobForm, JobStatusBadge)
- `src/components/layout/` -- Sidebar, Header, ThemeToggle
- `src/hooks/` -- TanStack Query hooks (useJobs, usePrices, useAdmin, useJobStream, useAuth, useTemplates) + useTheme
- `src/lib/` -- API client, types, i18n, utils
- `src/pages/admin/` -- Admin dashboard and job management

## Rules
- All API calls go through `src/lib/api.ts` (axios instance with `/api` base)
- Types in `src/lib/types.ts` must match backend Pydantic models
- i18n: both `en` and `ko` translations required in `src/lib/i18n.ts`
- shadcn/ui components live in `src/components/ui/` -- do not modify directly
- Agent.tsx uses react-markdown + remark-gfm for rendering chat responses
- Path alias: `@/` maps to `src/`
- Build: `npm run build` (tsc + vite), output to `dist/`
- Docker: use `Dockerfile.prod` (copies pre-built dist) for cross-platform builds
