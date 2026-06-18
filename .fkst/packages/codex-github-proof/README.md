# codex-github-proof

A conformant fkst substrate package that produces a **user-verifiable** artifact:
on each session start it asks the **codex agent** (not the Lua) to create a text
file at the root of `chronoai-shining/hr-fkst` by calling the GitHub REST API
**through the NyxID credential proxy** (`nyxid proxy request api-github ...`).

The file `fkst-codex-proof.txt` appearing in the repo, committed as the session
user, is end-to-end proof that the session spawned codex, codex used the in-pod
`nyxid` CLI with the per-session `NYXID_ACCESS_TOKEN`, and the `api-github`
credential proxy wrote to GitHub on the user's behalf.

The file contents are exactly (note the single trailing space):

```
This file was created by fkst-substrate cloud session. Written by codex agent via nyxid cli using service slug: api-github. 
```

## Why codex, not Lua

The Lua department deliberately does **no** GitHub work. It only builds a
self-contained prompt, calls `spawn_codex_sync`, and records the outcome. The
write is performed by the codex agent so the test verifies the *agent's* access
path (codex -> `nyxid` CLI -> `api-github` proxy -> GitHub), which is the
capability this package exists to prove.

## How it fires

The worker runs the engine with `fkst-framework supervise`, which only fires a
department when a raiser produces a consumed event (it injects no bootstrap
event, and the goal description is a file, not an event). So this package ships
a **cron** raiser (`raisers/proof_tick.lua`, `interval = "1s"`) whose first tick
lands within ~1s of supervise startup with no committed seed file. The
department consumes that tick and runs its `pipeline`, guarded by `once(...)` so
the effect runs exactly once per session rather than once per second. The codex
prompt is idempotent across sessions too: it updates the file (with its blob
`sha`) if it already exists.

## Layout

```
.fkst/packages/codex-github-proof/
  core.lua                                       # constants + prompt + result helpers (unit-tested)
  raisers/proof_tick.lua                         # cron trigger (produces proof_tick)
  departments/codex-github-proof/main.lua        # consumes proof_tick; spawn_codex_sync(prompt)
  departments/codex-github-proof/proof_test.lua  # unit tests for core.lua
  tests/run_department_test.lua                  # department test with a mocked codex CLI
```

## Requirements

At run time the worker image must provide `codex` and `nyxid` on `PATH`, and the
session must export `NYXID_ACCESS_TOKEN` + `NYXID_URL` (provisioned per session
by the control plane) for a user who has connected `api-github` with write
(`repo`) scope on NyxID.
