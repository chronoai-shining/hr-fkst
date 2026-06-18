-- hello department: on the first cron tick of a session, print "hello" to
-- stdout and send "hello" to the codex agent via the engine SDK.
local M = {}
local core = require("core")

M.spec = {
  consumes = { "hello_tick" },
  -- Mark the cron-tick subscription ephemeral so supervise does not require a
  -- durable store for this demo to run.
  ephemeral = { "hello_tick" },
  produces = { "hello_result" },
  stall_window = "5m",
}

-- `pipeline` is the engine's department handler: a GLOBAL function (not
-- M.pipeline). It receives Event{ queue, payload, ts } and runs in a per-event
-- `fkst-framework run` child whose stdout is captured by the supervisor.
function pipeline(event)
  -- The cron raiser fires every second; once() makes the effects run exactly
  -- once per session instead of once per tick.
  once(core.ONCE_KEY, function()
    -- (1) Deterministic stdout. `print` is the Lua base stdlib and writes to
    -- the run-child stdout (log.* would go to stderr instead).
    print(core.MESSAGE)

    -- (2) Send "hello" to the codex agent over the engine SDK. `codex` must be
    -- on PATH at run time (the worker image provides it).
    local result = spawn_codex_sync({
      prompt = core.MESSAGE,
      timeout = core.CODEX_TIMEOUT_SECONDS,
    })

    -- Trace the outcome without leaking codex stdout/stderr payloads.
    if core.codex_succeeded(result) then
      log.info(core.format_result(result))
    else
      log.warn("hello-codex: " .. core.format_result(result))
    end

    raise("hello_result", core.result_payload(result))
  end)
end

return M
