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

Next: the **LLM tool-loop** drops into this proven harness — goal mode / loop mode,
token/wall-clock/iteration budgets as hard ceilings, a scoped tool sandbox, and the
mailbox as the human-approval channel for risky actions.

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
