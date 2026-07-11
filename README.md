# roam

Leave a working agent on a remote box. `roam` dispatches an autonomous agent that
**roams to a VM, replicates itself there, and works while you're away** — on a
schedule or right now — then lets you attach back at any time to inspect and steer it.

One **static native binary** (built with [machin](https://github.com/javimosch/machin) —
no Python, no runtime, no deps). The same binary is both the local **controller** and
the remote **worker**; "self-replication" is literally `scp`-ing the executable.

**Landing + changelog:** [javimosch.github.io/roam](https://javimosch.github.io/roam)

**Proven end-to-end:** in a live run, a roam agent was dispatched to a remote box with the
goal *"add a unit test to the machin repo in a git worktree and open a PR"* — it cloned the
repo, wrote a passing Go test, parked on `git push` for out-of-band approval (the confirm-gate),
and filed a PR that was reviewed and **merged**
([machin#433](https://github.com/javimosch/machin/pull/433)). One static binary, no Python on
the target.

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

## Status

**Slice 1 — the skeleton (done, end-to-end on a real remote).** No LLM yet: a detached
worker loop that ticks trivial work into a SQLite journal, drains a steering mailbox at
each checkpoint, and is inspectable / steerable / stoppable — locally **and** on a remote
box the binary ships itself to.

```
# local (proves the machine)
roam send --to x --goal "…" --every 1 --local
# remote: scp this binary to the host, boot a detached worker there
roam send --to rbm21 --goal "…" --every 5
roam status rbm21     # JSON snapshot over ssh: status, tick, recent journal
roam attach rbm21     # live-stream the remote journal over ssh (Ctrl-C to detach)
roam steer  rbm21 "a note for the agent"
roam pause|resume|stop rbm21     # control, applied at the next checkpoint
```

A control target is a local `<jobid>`, a remote `<host>` (via its `~/.roam/hosts/<host>`
handle), or `last`. Remote ops re-run the **same** roam subcommand on the remote against
its own journal — ssh streams the output straight back, so `attach` is live over the pipe.
The worker detaches with `setsid` + closed stdin, so it survives the ssh session that
launched it. Verified on rbm21: `send` (self-replicate + boot) → `status`/`attach` →
`steer` → `pause` (froze) → `resume` (advanced) → `stop` (clean exit).

**Slice 2 — the LLM tool-loop (done).** The worker now runs a real agent: a manual
Anthropic Messages API tool-use loop, written in machin itself (raw HTTP — no SDK).

```
export ANTHROPIC_API_KEY=sk-ant-...
roam send --to rbm21 --allow-shell --goal "clone repo X, run its tests, write results to results.md"
roam attach rbm21        # watch it think + act, live over ssh
roam steer  rbm21 "focus on the failing integration test first"
roam stop   rbm21
```

- **Tools:** `read_file`, `write_file`, `finish`, and (gated behind `--allow-shell`)
  `run_shell`. File tools are confined to a per-job workdir (`~/.roam/work/<jobid>/`);
  `..`/absolute paths are refused, and `run_shell` runs with that cwd.
- **Trust layer** (what lets you actually walk away): **hard budgets** — `--max-iters`
  and `--tokens` freeze the run (`status: halted`) the moment either is hit; a
  **confirm-gate** (`--confirm`) parks destructive shell commands (`rm`, `dd`, `mkfs`,
  `git push`, `DROP TABLE`, `shutdown`, pipe-to-shell, …) for async approval
  (`status: awaiting`, the exact command in `pending`) — `roam approve` runs it,
  `roam deny` refuses it (the agent adapts), `roam stop` cancels. A **deny budget**
  (`--max-denials`, default 3) auto-halts a stubborn agent that keeps re-parking on
  destructive variants (it tried `sudo rm` after a denied `rm` in live testing), so it
  self-terminates instead of parking forever. A **goal-verify pass** (`--verify`) sends a
  `finish` to an independent judge that decides PASS/FAIL from *evidence* (the real workdir
  listing + action log), not the agent's self-report — a FAIL turns finish into "not done,
  keep working" (up to `--max-verify`, then halt), so the agent can't just claim success.
  It is **fail-open**: a judge that can't render a clear verdict is `inconclusive` and
  never blocks a completing agent (its teeth scale with the judge model's capability). The
  append-only
  **journal** records every model turn, tool call, result, and token cost; the mailbox
  is the **stop / steer / approve / deny** channel, applied at loop checkpoints.

**roam is non-interactive by design — one interface for humans and agents.** Every
command is one-shot (stdout = JSON, stderr = text, semantic exit codes); there's no TTY
prompt. The confirm-gate is therefore *async*: the worker parks and a supervisor
approves out-of-band. A human types `roam approve rbm21`; a supervising agent reads
`pending` from `roam status` JSON and calls `roam approve rbm21`. Identical surface.
- **Providers:** `--provider anthropic` (default; Anthropic Messages API), `--provider
  openai` (any OpenAI-compatible endpoint — OpenRouter, etc. — via `--api-base`), or
  `--provider debri` (delegate to the [`devin`](https://devin.ai) CLI via
  [debri](https://github.com/javimosch/debri) — see below). The LLM providers speak the same
  tools/sandbox/budget machinery; only the wire shape differs. Key from `ROAM_API_KEY` or
  `ANTHROPIC_API_KEY`.
- **Model:** default `claude-opus-4-8` (`--model` to override). Non-streaming,
  `max_tokens 16000`, transient `429`/`5xx` retried with backoff.
- The assistant turn is replayed **verbatim** each iteration, so tool-use pairing stays
  correct across turns.

**`--provider debri` — a subscription engine (no per-token cost).** Instead of roam's own
LLM tool-loop, the worker hands the whole goal to the [`devin`](https://devin.ai) CLI (the
SWE-1.x models) via [debri](https://github.com/javimosch/debri), streaming its JSONL into
the journal. roam keeps everything around it — dispatch, self-replication, `attach`, `stop`
— but the agent runs on a **flat Devin subscription**, so a long open-ended build costs the
same whether it thinks for one minute or thirty. No API key, no `--tokens` budget; those
flags are moot for this provider.

The target needs three things (no source, no build) — the **debri binary**, the
**`devin`** CLI (authenticated), and **`tmux`**:

```bash
# debri: one prebuilt binary from its GitHub releases (no codebase needed)
curl -fsSL https://github.com/javimosch/debri/releases/latest/download/debri \
  -o ~/.local/bin/debri && chmod +x ~/.local/bin/debri
devin auth login          # authenticate the devin CLI (a Devin subscription)
# tmux from your package manager (debri drives devin inside a tmux session)
```

```bash
roam send --to my-vm --provider debri --model SWE-1.7 \
  --goal "clone repo X, build the thing, run its tests, push a branch"
roam attach my-vm     # tail devin's output over ssh
roam stop   my-vm     # SIGTERMs debri so it tears down the devin session cleanly
```

- Flags: `--debri-perm auto|dangerous` (devin permission mode, default `dangerous`) and
  `--debri-stable <ms>` (debri's silence safety-cap, default `300000`). A done-marker is
  appended to the goal so a cooperative session ends promptly instead of waiting out the cap.
- **Use [debri](https://github.com/javimosch/debri) ≥ v1.2.0.** `devin -p` (print mode)
  buffers its whole response and shows no incremental pane output during long operations,
  which used to trip two things: debri would kill a quiet-but-working session at the
  stable-timeout, and the captured content came back empty. **debri v1.2.0 fixes both** —
  it treats process-exit (the pane returning to a shell) as the completion signal rather
  than silence, and reads devin's redirected stdout for the response. So with v1.2.0+,
  `--debri-stable` is just a backstop for a genuinely wedged pane, not a knob you have to
  tune to survive devin's silent startup, and the journal gets devin's real final output.
- **Still true regardless of version:** devin `-p` streams no *incremental* progress (its
  output lands at completion), so for live mid-task insight the **working directory is the
  truthful signal**; and each run completes a **bounded slice** of a big brief then exits —
  so hand it *focused* slices rather than one giant goal.
- **Proven end-to-end:** built [machin-hill-climb](https://github.com/javimosch/machin-hill-climb)
  — a Box2D + raylib physics game **and** a pure-MFL WebAssembly port
  ([live](https://javimosch.github.io/machin-hill-climb/)) — dispatched through this engine
  on SWE-1.7, verified compiling + playtested.

**Live-proven on rbm21** (OpenRouter, `poolside/laguna-xs-2.1`, `--allow-shell`): a
dispatched agent self-replicated, ran `uname`/`nproc`/`free`/`df` on the box, wrote a
Markdown `report.md`, and finished — watched live over ssh via `attach`.

Verified: the loop mechanics (write→read→finish, multi-turn accumulation, budget halt,
workdir-escape refusal, shell gate, mid-loop stop) driven end-to-end through a local
mock of `/v1/messages`; and the real TLS request path against `api.anthropic.com`
(a dummy key returns `401`, i.e. a well-formed request reached auth).

Next: adaptive-thinking support (replay thinking blocks), a wall-clock budget, and a
confirm-gate for destructive actions (park → approve via the mailbox → resume).

## Design

- **Storage** (per job): `~/.roam/<jobid>.db`, SQLite in **WAL** mode so the worker
  (writer) and `status`/`attach` (readers) can hold it concurrently.
  - `state(k,v)` — status · goal · every · tick · host · started
  - `journal(id,ts,kind,msg)` — append-only audit trail (the thing you'll `pull`)
  - `mailbox(id,ts,consumed,cmd,arg)` — steering, drained at safe checkpoints
- **No pidfiles/signals.** Control is via mailbox messages the worker applies at loop
  boundaries (`stop` = a message, not a kill) — you can't safely interrupt mid-work.
- **Agent-first CLI:** stdout = JSON answer, stderr = human/error text, semantic exits.

## Build

```
machin encode roam.src > roam.mfl && machin build roam.mfl -o roam
```
