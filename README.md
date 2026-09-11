# roam

**One binary. Your servers. Your agents.**

roam runs autonomous agents on your own servers over SSH — detached, budgeted,
sandboxed. The moment one reaches for something destructive, it stops and asks.
Approve or deny from your phone. No Docker, no runtime, no per-seat subscription.

- **7 MB static binary** — no Python, no Node, no deps. `scp` it to any Linux box.
- **SSH-native** — agents run on your existing servers. No containers, no sandboxes.
- **Self-hosted approval panel** — free, MIT licensed. Or use the hosted hub.
- **Pay per run, not per seat** — €0.01 + token cost × 1.3. No monthly fee.
- **Multi-provider** — Anthropic, OpenAI (any OpenAI-compatible endpoint), or Devin SWE-1.x.
- **Worker routing** — route GPU agents to GPU boxes, Docker agents to Docker hosts, all within one tenant.

Built with [machin](https://github.com/javimosch/machin) — one static native binary
is both the local controller and the remote worker. "Self-replication" is literally
`scp`-ing the executable.

**→ Try the hosted hub: [roam.intrane.fr](https://roam.intrane.fr)** — no keys to manage,
per-run billing, web panel, worker coordination. Join the waitlist for early access.

**Quickstart:** [docs/quickstart.md](docs/quickstart.md) ·
**Hub API:** [docs/hub-api.md](docs/hub-api.md) ·
**Panel:** [roam-panel](https://github.com/javimosch/roam-panel) ·
**Releases:** [GitHub Releases](https://github.com/javimosch/roam/releases)

## Quickstart

```bash
curl -fsSL https://github.com/javimosch/roam/releases/latest/download/roam-x86_64-linux -o roam
chmod +x roam
export ANTHROPIC_API_KEY="sk-ant-..."
./roam send --local --provider anthropic --allow-shell --confirm \
  --goal "list files in this directory and summarize the project"
./roam status last     # JSON snapshot
./roam attach last     # stream the journal live
```

See [docs/quickstart.md](docs/quickstart.md) for the full 5-minute guide
(remote dispatch, approval panel, hosted hub, debri provider).

## Install

Grab the static binary from [Releases](https://github.com/javimosch/roam/releases)
(`roam-x86_64-linux` — bundles SQLite + OpenSSL + a CA store, runs FROM scratch on any
x86-64 Linux, no deps):

```bash
curl -fsSL https://github.com/javimosch/roam/releases/latest/download/roam-x86_64-linux -o roam
chmod +x roam && ./roam help
```

Or build from source (needs the [machin](https://github.com/javimosch/machin) compiler):

```bash
make build      # dynamic (links host libsqlite3 + OpenSSL)
make release    # fully-static roam-x86_64-linux
```

## How it works

1. `roam send --local` or `roam send --to <host>` creates a job.
2. The agent runs a tool loop: `read_file`, `write_file`, `run_shell` (gated by `--allow-shell`), `finish`.
3. Destructive commands (`rm`, `git push --force`, `DROP TABLE`, `shutdown`…) park for approval.
4. You approve, deny, steer, or stop — from the terminal, the web panel, or a phone tap.
5. The worker ends in `done`, `halted`, `stopped`, or `error`.

```bash
roam send --to my-vm --provider anthropic --allow-shell --confirm \
  --goal "check disk usage and clean up logs older than 30 days"
roam attach my-vm     # stream the journal over SSH
roam approve my-vm    # let the parked command proceed
roam stop   my-vm     # cancel the agent
```

## Approve from your phone

[**roam-panel**](https://github.com/javimosch/roam-panel) is a self-hostable control-plane
hub — one binary, HTTP + SQLite + a mobile web dashboard. Point a job at your panel and
the worker mirrors its journal + status there and polls for decisions:

```bash
roam send --to my-vm --provider anthropic --confirm \
  --hub https://your-panel-url --hub-token "$ROAM_HUB_TOKEN" \
  --goal "clone repo X, run its tests, then git push a branch"
```

You get an email the moment it parks. Approve or deny from the web panel — no SSH needed.
The panel is MIT licensed, self-hostable, and supports optional SSO via
[Portier](https://github.com/javimosch/portier).

For the hosted hub (`hub.roam.intrane.fr`), join the waitlist at
[roam.intrane.fr](https://roam.intrane.fr). Pay per run, no monthly subscription.

## Hosted hub

Don't want to manage API keys, billing, and worker coordination? The hosted hub
at [hub.roam.intrane.fr](https://hub.roam.intrane.fr) handles it for you:

- **No model keys** — workers hold no API keys. Every LLM call goes through the
  hub's metered proxy. You pick the model per agent.
- **Per-run billing** — €0.01 + token cost × 1.3 per run. A typical coding task
  costs €0.02–€0.10. Top up your wallet with a card via Stripe. No monthly fee.
- **Worker routing** — set a `selector` on your agent spec
  (`"selector":"gpu=true"`) and start workers with matching labels
  (`roam worker --label gpu=true --name gpu-box-01`). The hub routes runs to
  the right workers within a single tenant.
- **Multiple workers** — run N workers on N machines with the same token.
  Each gets a different run from the queue. Horizontal scaling, one wallet.
- **Webhook triggers** — `POST /t/<agent_id>/<secret>` to trigger a run from
  GitHub Actions, cron, or any HTTP source.
- **Auto-provisioning** — `GET /v1/whoami` with any Bearer token creates a
  tenant instantly. No email, no signup. `POST /app/claim` to attach an email
  later.

```bash
# Start a worker on your server — no API key needed
roam worker --hub https://hub.roam.intrane.fr --token rhw_... \
  --label gpu=true --name gpu-box-01

# Trigger a run from anywhere
curl -X POST https://hub.roam.intrane.fr/t/<agent_id>/<secret>
```

See [docs/hub-api.md](docs/hub-api.md) for the full API. Join the waitlist at
[roam.intrane.fr](https://roam.intrane.fr).

## Providers

- **`--provider anthropic`** (default) — Anthropic Messages API. Key from `ANTHROPIC_API_KEY` or `ROAM_API_KEY`.
- **`--provider openai`** — any OpenAI-compatible endpoint (OpenRouter, etc.) via `--api-base`.
- **`--provider debri`** — delegates to the [`devin`](https://devin.ai) CLI (SWE-1.x models)
  via [debri](https://github.com/javimosch/debri). Subscription-based, no per-token cost.
  See [docs/quickstart.md](docs/quickstart.md) for setup.

All providers share the same tools, sandbox, budget, and confirm-gate machinery.

## Trust layer

- **Hard budgets** — `--max-iters` and `--tokens` freeze the run (`status: halted`) when hit.
- **Confirm-gate** — `--confirm` parks destructive commands for async approval.
- **Deny budget** — `--max-denials` (default 3) auto-halts an agent that keeps re-parking on destructive variants.
- **Goal-verify** — `--verify` sends `finish` to an independent judge that checks evidence, not self-report.
- **Workdir sandbox** — file tools confined to `~/.roam/work/<jobid>/`; `..` and absolute paths refused.
- **Append-only journal** — every model turn, tool call, result, and token cost recorded.

## Agent-first discovery

```bash
roam guide              # structured JSON: model, loop, concepts, examples, gotchas
roam guide --human      # readable Markdown
roam help-json           # machine-readable commands, flags, exits, and environment
```

Controller errors use typed JSON on stderr and semantic exits: `80-89` for invalid input,
`90-99` for missing resources or authentication, `100-109` for remote/external failures.

## Telemetry — opt-IN, off by default

roam reports **nothing** unless you run `roam telemetry --telemetry-on`. A fresh install
makes zero outbound connections beyond the work you asked it to do — verified with `strace`.

If enabled, it sends version, os/arch, which verb ran and whether it failed — never prompts,
keys, output, hostnames or paths. `roam telemetry` prints the exact payload.
[cli-telemetry-spec](https://github.com/javimosch/cli-telemetry-spec) §2.4.

## Design

- **Storage** (per job): `~/.roam/<jobid>.db`, SQLite in WAL mode.
  - `state(k,v)` — status · goal · every · tick · host · started
  - `journal(id,ts,kind,msg)` — append-only audit trail
  - `mailbox(id,ts,consumed,cmd,arg)` — steering, drained at safe checkpoints
- **No pidfiles/signals.** Control is via mailbox messages applied at loop boundaries.
- **Agent-first CLI:** stdout = JSON, stderr = human/error text, semantic exits.

## Build

```
machin encode roam.src > roam.mfl && machin build roam.mfl -o roam
```
