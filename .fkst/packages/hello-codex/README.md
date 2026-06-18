# hello-codex

A minimal, conformant fkst substrate package whose only job is to prove a
session ran end to end. On each session start it does exactly two observable
things, **once**:

1. prints `hello` to stdout (plain Lua `print`), and
2. sends `hello` to the codex agent via the engine SDK
   `spawn_codex_sync({ prompt = "hello", timeout = 120 })`, logs the
   `exit_code`/`log_path`, and raises a `hello_result` event.

## How it fires

The worker runs the engine with `fkst-framework supervise`, which only fires a
department when a raiser produces a consumed event (it injects no bootstrap
event, and the goal description is a file, not an event). So this package ships
a **cron** raiser (`raisers/hello_tick.lua`, `interval = "1s"`) whose first
tick lands within ~1s of supervise startup with no committed seed file. The
`hello` department consumes that tick and runs its `pipeline`, guarded by
`once(...)` so the effects run exactly once per session rather than once per
second.

## Layout

```
.fkst/packages/hello-codex/
  core.lua                          # shared, unit-testable helpers
  raisers/hello_tick.lua            # cron trigger (produces hello_tick)
  departments/hello/main.lua        # consumes hello_tick; print + spawn_codex_sync
  departments/hello/hello_test.lua  # unit tests for core.lua
  tests/run_department_test.lua      # department test with a mocked codex CLI
```

## Requirements

`codex` must be on `PATH` at run time (the worker image provides it).
