# roam

Leave a working agent on a remote box. `roam` dispatches an autonomous agent that
**roams to a VM, replicates itself there, and works while you're away** — on a
schedule or right now — then lets you attach back at any time to inspect and steer it.

One **static native binary** (built with [machin](https://github.com/javimosch/machin) —
no Python, no runtime, no deps). The same binary is both the local **controller** and
the remote **worker**; "self-replication" is literally `scp`-ing the executable.

## Status

**Slice 1a — the skeleton (done).** No LLM yet: a detached worker loop that ticks
trivial work into a SQLite journal, drains a steering mailbox at each checkpoint, and is
inspectable / steerable / stoppable. Proves the whole machine locally before any network.

```
roam send --to rbm21 --goal "…" --every 1 --local   # spawn a detached worker
roam status last                                     # JSON snapshot: status, tick, recent journal
roam attach last                                     # live-stream the journal (Ctrl-C to detach)
roam steer  last "a note for the agent"              # drop a steering message in its mailbox
roam pause|resume|stop last                          # control, applied at the next checkpoint
```

Next: **slice 1b** — the ssh `send`-to-remote layer (scp the binary, launch detached over
ssh, control ops over ssh against the remote journal), end-to-end on rbm21. Then the LLM
tool-loop drops into this proven harness (goal mode / loop mode, budgets, tool sandbox).

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
