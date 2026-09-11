# roam quickstart — 5 minutes to your first agent

## 1. Download

```bash
curl -fsSL https://github.com/javimosch/roam/releases/latest/download/roam-x86_64-linux -o roam
chmod +x roam && ./roam help
```

One static binary. No Python, no Node, no Docker. Works on any x86-64 Linux.

## 2. Set your API key

roam supports Anthropic, OpenAI, and any OpenAI-compatible endpoint:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
# or
export OPENAI_API_KEY="sk-..."
```

For the debri provider (Devin SWE-1.x models, subscription-based, no API key):
```bash
# Install debri + devin CLI instead — see the README for details
curl -fsSL https://github.com/javimosch/debri/releases/latest/download/debri -o ~/.local/bin/debri
chmod +x ~/.local/bin/debri
devin auth login
```

## 3. Run your first agent

```bash
./roam send --local --provider anthropic --allow-shell --goal "list the files in this directory and summarize what this project does"
```

The agent runs locally, writes to a workdir under `~/.roam/work/`, and exits when done.

Watch it work:
```bash
./roam status last     # JSON snapshot
./roam attach last     # stream the journal live
```

## 4. Approve destructive commands

Add `--confirm` to gate destructive actions. The agent parks and waits for your approval:

```bash
./roam send --local --provider anthropic --allow-shell --confirm \
  --goal "delete all .tmp files in /tmp and report what was removed"
```

Approve or deny from the terminal:
```bash
./roam approve last    # let it proceed
./roam deny last       # stop it
```

## 5. Dispatch to a remote server

```bash
./roam send --to my-vm --provider anthropic --allow-shell --confirm \
  --goal "check disk usage and clean up logs older than 30 days"
```

roam copies itself to the remote box via SSH, runs detached, and parks on
destructive commands. Attach from anywhere:

```bash
./roam attach my-vm    # stream the journal over SSH
./roam status my-vm    # JSON snapshot
```

## 6. Self-host the approval panel (optional)

The panel gives you a web UI for approvals — see every agent across every
server, approve/deny from your browser, and get email notifications.

```bash
# Download roam-panel from GitHub Releases
curl -fsSL https://github.com/javimosch/roam-panel/releases/latest/download/roam-panel-x86_64-linux -o roam-panel
chmod +x roam-panel

# Start it
ROAM_PANEL_SECRET=$(openssl rand -hex 32) ./roam-panel serve --port 8099
```

Then dispatch agents with `--hub` pointing to your panel:

```bash
./roam send --local --provider anthropic --allow-shell --confirm \
  --hub http://localhost:8099 --hub-token <your-panel-token> \
  --goal "fix the failing tests in src/"
```

The agent parks in the panel. Open `http://localhost:8099` in your browser
to approve or deny.

## 7. Use the hosted hub (optional)

Instead of self-hosting, use the hosted hub at `hub.roam.intrane.fr`:
agents phone home, you approve from anywhere, and you pay per run
(€0.01 + token cost × 1.3). No monthly subscription, no API key needed —
the hub proxies LLM calls through OpenRouter.

```bash
./roam send --to my-vm --provider anthropic --allow-shell --confirm \
  --hub https://hub.roam.intrane.fr --hub-token <your-hub-token> \
  --goal "audit the nginx config and fix any security issues"
```

Join the waitlist at [roam.intrane.fr](https://roam.intrane.fr) for hosted access.

## Next steps

- `./roam guide --human` — full command reference
- `./roam help-json` — machine-readable command catalog
- [README](../README.md) — architecture, providers, and design docs
- [GitHub](https://github.com/javimosch/roam) — source and issues
