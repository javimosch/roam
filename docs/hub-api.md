# roam-hub API reference

The hosted hub (`hub.roam.intrane.fr`) is the control plane for scheduled,
metered agent runs. Workers hold no API keys — every LLM call proxies through
the hub, which counts exact tokens, accumulates cost, and charges per run via
[peage](https://peage.intrane.fr).

## Authentication

Two token types, both returned once at signup:

| Token | Prefix | Used by | Scope |
|-------|--------|---------|-------|
| **Tenant token** | `rh_` | You (the owner) | Agent CRUD, run management, approve/deny |
| **Worker token** | `rhw_` | The roam worker process | Pull work, LLM proxy, stream events, report done |

Both are sent as `Authorization: Bearer <token>`.

## Signup

### POST /v1/signup

```bash
curl -X POST https://hub.roam.intrane.fr/v1/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","peage_wallet":"pw_..."}'
```

Response:
```json
{"ok":true,"token":"rh_...","worker_token":"rhw_..."}
```

One tenant per email. The `peage_wallet` is a peage wallet token (`pw_...`) for
billing — see [peage.intrane.fr/llms.txt](https://peage.intrane.fr/llms.txt).

### GET /v1/whoami (cli-trial-spec)

Any Bearer token auto-provisions a tenant — no email, no signup needed.
The token IS the credential. Generate any token and call whoami:

```bash
curl https://hub.roam.intrane.fr/v1/whoami \
  -H "Authorization: Bearer rh_my_random_token_123"
```

First call (auto-provisions):
```json
{"v":"1","tenant_id":"...","email":"","wallet_attached":false,
 "claimed":false,"plan":"pay_per_run",
 "worker_token":"rhw_...","auto_provisioned":true}
```

Subsequent calls (returns existing):
```json
{"v":"1","tenant_id":"...","email":"","wallet_attached":false,
 "claimed":false,"plan":"pay_per_run"}
```

### POST /app/claim

Attach an email to an existing tenant (recovery + billing):

```bash
curl -X POST https://hub.roam.intrane.fr/app/claim \
  -H "Authorization: Bearer rh_my_random_token_123" \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com"}'
```

Response:
```json
{"v":"1","claimed":true,"email":"you@example.com"}
```

### POST /v1/wallet

Set or update your peage wallet:

```bash
curl -X POST https://hub.roam.intrane.fr/v1/wallet \
  -H "Authorization: Bearer rh_..." \
  -H "Content-Type: application/json" \
  -d '{"wallet_token":"pw_..."}'
```

## Agent management

### POST /v1/agents

Create an agent spec (a spec, not a process — runs are the executions):

```bash
curl -X POST https://hub.roam.intrane.fr/v1/agents \
  -H "Authorization: Bearer rh_..." \
  -H "Content-Type: application/json" \
  -d '{
    "name": "nightly-tests",
    "prompt": "clone repo X, run tests, report failures",
    "model": "claude-sonnet-4-20250514",
    "every_secs": 86400,
    "budget_microeur": 500000,
    "report_url": "https://your-webhook.example.com/run-done",
    "kind": "agent",
    "trigger_mode": "ignore"
  }'
```

Response: `{"ok":true,"id":"ag_...","trigger_secret":"ts_..."}`

Fields:
- `name` — display name
- `prompt` — the goal instruction
- `model` — model identifier (e.g., `claude-sonnet-4-20250514`)
- `every_secs` — run interval in seconds (0 = webhook-only)
- `budget_microeur` — hard budget in micro-EUR (10000 µ€ = €0.01)
- `report_url` — webhook called when a run finishes
- `kind` — `agent` (LLM tool-loop, default) or `script` (deterministic steps)
- `trigger_mode` — `ignore` (default) or `inject` (webhook payload injected into prompt)
- `steps` — JSON step list (for `kind: "script"`)
- `steps_url` — GitOps step source (fetched fresh at claim time)

### GET /v1/agents

List your agents:

```bash
curl https://hub.roam.intrane.fr/v1/agents \
  -H "Authorization: Bearer rh_..."
```

### POST /v1/agent/pause · /v1/agent/resume · /v1/agent/delete

```bash
curl -X POST https://hub.roam.intrane.fr/v1/agent/pause \
  -H "Authorization: Bearer rh_..." \
  -H "Content-Type: application/json" \
  -d '{"id":"ag_..."}'
```

## Webhook trigger

### POST /t/<agent_id>/<secret>

Queue a run immediately (bypasses the interval schedule):

```bash
curl -X POST https://hub.roam.intrane.fr/t/ag_.../ts_... \
  -H "Content-Type: application/json" \
  -d '{"event":"push","repo":"myorg/myrepo"}'
```

If the agent's `trigger_mode` is `inject`, the body is appended to the prompt.

## Run management

### GET /v1/runs?agent=<agent_id>

List recent runs (last 50) for an agent:

```bash
curl "https://hub.roam.intrane.fr/v1/runs?agent=ag_..." \
  -H "Authorization: Bearer rh_..."
```

### GET /v1/run?id=<run_id>

Run detail with full journal:

```bash
curl "https://hub.roam.intrane.fr/v1/run?id=run_..." \
  -H "Authorization: Bearer rh_..."
```

### POST /v1/run/approve · /v1/run/deny

Approve or deny a parked run (when the worker called `needs-human`):

```bash
curl -X POST https://hub.roam.intrane.fr/v1/run/approve \
  -H "Authorization: Bearer rh_..." \
  -H "Content-Type: application/json" \
  -d '{"id":"run_..."}'
```

### POST /v1/run/kill

Kill a running or queued run (starves the LLM loop within one turn):

```bash
curl -X POST https://hub.roam.intrane.fr/v1/run/kill \
  -H "Authorization: Bearer rh_..." \
  -H "Content-Type: application/json" \
  -d '{"id":"run_..."}'
```

## Worker protocol

These endpoints are used by the `roam worker` process, not by humans directly.

### GET /v1/work

Pull the oldest queued run. Returns 204 when idle. Claiming flips
`queued → running` (atomic, guards against double-claim):

```bash
curl https://hub.roam.intrane.fr/v1/work \
  -H "Authorization: Bearer rhw_..."
```

Response (200):
```json
{
  "ok": true,
  "run_id": "run_...",
  "agent_id": "ag_...",
  "name": "nightly-tests",
  "prompt": "clone repo X, run tests...",
  "model": "claude-sonnet-4-20250514",
  "budget_microeur": 500000,
  "kind": "agent"
}
```

### POST /v1/llm

Metered LLM proxy. The worker sends the upstream messages payload; the hub
forwards to the provider with its own key, counts tokens, and accumulates cost.
The run ID travels in the `X-Roam-Run` header:

```bash
curl -X POST https://hub.roam.intrane.fr/v1/llm \
  -H "Authorization: Bearer rhw_..." \
  -H "X-Roam-Run: run_..." \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-sonnet-4-20250514","messages":[...],"max_tokens":16000}'
```

The hub refuses if the run is killed or the budget is exhausted.

### POST /v1/run/events

Stream a journal entry:

```bash
curl -X POST https://hub.roam.intrane.fr/v1/run/events \
  -H "Authorization: Bearer rhw_..." \
  -H "Content-Type: application/json" \
  -d '{"run_id":"run_...","kind":"tool_call","data":"{\"tool\":\"run_shell\",\"cmd\":\"ls\"}"}'
```

### POST /v1/run/needs-human

Park the run for owner approval (sets status to `awaiting`):

```bash
curl -X POST https://hub.roam.intrane.fr/v1/run/needs-human \
  -H "Authorization: Bearer rhw_..." \
  -H "Content-Type: application/json" \
  -d '{"run_id":"run_...","command":"rm -rf /var/log/old"}'
```

### GET /v1/run/decision?run=<run_id>

Poll for the owner's decision (the worker polls this every second while parked):

```bash
curl "https://hub.roam.intrane.fr/v1/run/decision?run=run_..." \
  -H "Authorization: Bearer rhw_..."
```

Response: `{"ok":true,"decision":""}` (empty = still waiting),
`"approve"`, `"deny"`, or `"stop"` (if killed).

### POST /v1/run/done

Close the run, bill it, and fire the report webhook:

```bash
curl -X POST https://hub.roam.intrane.fr/v1/run/done \
  -H "Authorization: Bearer rhw_..." \
  -H "Content-Type: application/json" \
  -d '{"run_id":"run_...","exit_reason":"complete","result":"all tests passed"}'
```

## Billing

Per finished run:
```
charge_cents = ceil(cost_microeur × 1.3 / 10000) + 1
```

- `cost_microeur` — exact token cost accumulated from the LLM proxy
- `× 1.3` — 30% margin
- `+ 1` — €0.01 flat fee per run
- Idempotent on run ID (retried `/v1/run/done` charges once)
- Solvency is probed before queueing (peage balance > €0.05)
- Insolvency is a journal event, never a silent skip

## Discovery

- `GET /_health` — `{"ok":true,"service":"roam-hub"}`
- `GET /v1/guide` — machine-readable endpoint list
- `GET /llms.txt` — summary for agent consumption
