# roam

Leave a working agent on a remote box. `roam` dispatches an autonomous agent that
**roams to a VM, replicates itself there, and works while you're away** — on a
schedule or right now — then lets you attach back at any time to inspect and steer it.

One **static native binary** (built with [machin](https://github.com/javimosch/machin) —
no Python, no runtime, no deps). The same binary is both the local **controller** and
the remote **worker**; "self-replication" is literally `scp`-ing the executable.

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
  self-terminates instead of parking forever. The append-only
  **journal** records every model turn, tool call, result, and token cost; the mailbox
  is the **stop / steer / approve / deny** channel, applied at loop checkpoints.

**roam is non-interactive by design — one interface for humans and agents.** Every
command is one-shot (stdout = JSON, stderr = text, semantic exit codes); there's no TTY
prompt. The confirm-gate is therefore *async*: the worker parks and a supervisor
approves out-of-band. A human types `roam approve rbm21`; a supervising agent reads
`pending` from `roam status` JSON and calls `roam approve rbm21`. Identical surface.
- **Providers:** `--provider anthropic` (default; Anthropic Messages API) or
  `--provider openai` (any OpenAI-compatible endpoint — OpenRouter, etc. — via
  `--api-base`). Both speak the same tools/sandbox/budget machinery; only the wire shape
  differs. Key from `ROAM_API_KEY` or `ANTHROPIC_API_KEY`.
- **Model:** default `claude-opus-4-8` (`--model` to override). Non-streaming,
  `max_tokens 16000`, transient `429`/`5xx` retried with backoff.
- The assistant turn is replayed **verbatim** each iteration, so tool-use pairing stays
  correct across turns.

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
