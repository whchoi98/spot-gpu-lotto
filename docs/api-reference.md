# API Reference

## Base URL
- Local: `http://localhost:8000/api`
- Production: `https://<cloudfront-domain>/api`

## Authentication
- Cognito JWT via ALB (production)
- Disabled in dev (`AUTH_ENABLED=false`)

---

## Health

### Health Check
```
GET /healthz
```
**Response** `200 OK` — `{"status": "ok"}`

### Readiness Check
```
GET /readyz
```
**Response** `200 OK` — `{"status": "ready"}`

---

## Jobs

### Submit Job
```
POST /api/jobs
```

**Request Body**

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `user_id` | string | No | `"anonymous"` | User identifier |
| `image` | string | No | `nvidia/cuda:12.0-base` | Container image |
| `command` | string[] | No | `["nvidia-smi"]` | Command to execute |
| `instance_type` | string | No | `g6.xlarge` | GPU instance type |
| `gpu_type` | string | No | `l4` | GPU type |
| `gpu_count` | integer | No | `1` | Number of GPUs |
| `storage_mode` | string | No | `s3` | `s3` or `fsx` |
| `checkpoint_enabled` | boolean | No | `false` | Enable checkpointing |
| `webhook_url` | string | No | - | Webhook for status updates |

**Response** `200 OK`
```json
{"job_id": "uuid", "status": "queued", "message": "Job queued"}
```

### Get Job
```
GET /api/jobs/{job_id}
```
**Response** `200 OK` — Full `JobRecord` object

### Cancel Job
```
DELETE /api/jobs/{job_id}
```
**Response** `200 OK` — `{"status": "cancelling"}`

### Stream Job Status (SSE)
```
GET /api/jobs/{job_id}/stream
```
**Response** `text/event-stream` — Server-Sent Events with status updates

### Set Webhook
```
PUT /api/settings/webhook
```
**Request Body** `{"user_id": "...", "webhook_url": "https://..."}`

---

## Prices

### Get Spot Prices
```
GET /api/prices
```
**Response** `200 OK`
```json
[{"region": "us-east-1", "instance_type": "g6.xlarge", "price": 0.3456}]
```

---

## Templates

### List Templates
```
GET /api/templates
```

### Create Template
```
POST /api/templates
```
**Request Body** — `TemplateEntry` object

### Delete Template
```
DELETE /api/templates/{name}
```

---

## Upload

### Get Presigned URL
```
POST /api/upload/presign
```
**Request Body** `{"filename": "model.tar.gz", "user_id": "..."}`
**Response** `200 OK` — `{"upload_url": "https://s3...", "s3_key": "..."}`

---

## Admin

### List All Jobs
```
GET /api/admin/jobs
```

### Force Delete Job
```
DELETE /api/admin/jobs/{job_id}
```

### Retry Job
```
POST /api/admin/jobs/{job_id}/retry
```

### Get Regions
```
GET /api/admin/regions
```

### Update Region Capacity
```
PUT /api/admin/regions/{region}/capacity
```
**Request Body** `{"capacity": 10}`

### Get Stats
```
GET /api/admin/stats
```

---

## Agent

### Chat with AI Agent
```
POST /api/agent/chat
```

**Request Body**

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `message` | string | Yes | - | User message |
| `history` | ChatMessage[] | No | `[]` | Conversation history (`{role, content}`) |

**Response** `200 OK`
```json
{
  "content": "Markdown response text",
  "model": "global.anthropic.claude-sonnet-4-6",
  "actions": [
    {
      "action": "submit_job",
      "instance_type": "g6.xlarge",
      "image": "nvidia/cuda:12.2.0-runtime-ubuntu22.04",
      "command": "nvidia-smi",
      "gpu_count": 1,
      "region": "us-east-2",
      "reason": "cheapest at $0.23/hr"
    }
  ]
}
```

**Notes**
- Uses Bedrock Converse API with real-time Redis context (prices, stats, capacity)
- `actions` array contains proposed job submissions (hybrid approval model)
- Frontend renders proposals as approval buttons; user must confirm before execution

---

## Error Codes

| Code | Description |
|------|-------------|
| 400 | Bad Request — Invalid parameters |
| 401 | Unauthorized — Missing or invalid Cognito JWT |
| 404 | Not Found — Job or resource does not exist |
| 500 | Internal Server Error |

## Rate Limits
- CloudFront WAF: 2000 req/5min per IP
- `/api/prices` cached 30s at CloudFront edge
