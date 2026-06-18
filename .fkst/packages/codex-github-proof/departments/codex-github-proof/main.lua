-- codex-github-proof department: on the first cron tick of a session, instruct
-- the codex agent (via the engine SDK) to create a text file at the root of the
-- target repo THROUGH the nyxid CLI + api-github proxy. The file write is done
-- BY CODEX, not by this Lua -- the Lua only builds the prompt, spawns codex, and
-- records the outcome. That keeps the test honest: the artifact in the repo is
-- proof the agent reached GitHub via the user's brokered credential.
local M = {}
local core = require("core")

M.spec = {
  consumes = { "proof_tick" },
  -- Mark the cron-tick subscription ephemeral so supervise does not require a
  -- durable store for this probe to run.
  ephemeral = { "proof_tick" },
  produces = { "proof_result" },
  -- Generous stall window: codex runs several shell calls before returning.
  stall_window = "10m",
}

-- `pipeline` is the engine's department handler: a GLOBAL function (not
-- M.pipeline). It receives Event{ queue, payload, ts } and runs in a per-event
-- `fkst-framework run` child whose stdout is captured by the supervisor.
function pipeline(event)
  -- The cron raiser fires every second; once() makes the effect run exactly
  -- once per session instead of once per tick.
  once(core.ONCE_KEY, function()
    -- Deterministic, log-safe marker on the run-child stdout so the session log
    -- shows what was attempted (the actual write happens inside codex).
    print(string.format(
      "codex-github-proof: instructing codex to create %s in %s via %s",
      core.FILE_PATH, core.REPO, core.SERVICE_SLUG))

    -- Hand codex the self-contained instruction. `codex` must be on PATH at run
    -- time (the worker image provides it); NYXID_ACCESS_TOKEN / NYXID_URL are
    -- exported into the run env so the agent's `nyxid` calls authenticate.
    local result = spawn_codex_sync({
      prompt = core.build_prompt(),
      timeout = core.CODEX_TIMEOUT_SECONDS,
    })

    -- Trace the outcome without leaking codex stdout/stderr payloads.
    if core.codex_succeeded(result) then
      log.info(core.format_result(result))
    else
      log.warn("codex-github-proof: " .. core.format_result(result))
    end

    raise("proof_result", core.result_payload(result))
  end)
end

return M
