-- Shared, side-effect-free helpers for the hello-codex package.
-- Kept here (not inline in the department) so the prompt/result logic is
-- unit-testable without spawning a real codex subprocess.
local M = {}

-- The message sent to the codex agent and printed to stdout. Constant by
-- design: this package is a deterministic conformance/dogfood probe, not a
-- goal-driven department, so it never reads goal.json.
M.MESSAGE = "hello"

-- Per-session idempotency key. The cron raiser fires every second; guarding
-- the effects with once(KEY, fn) makes them run exactly once per session
-- instead of once per tick.
M.ONCE_KEY = "hello-codex/fired"

-- Wall-clock cap (seconds) for the codex subprocess. Small but sane: the
-- prompt is a single word, so it should return well under two minutes.
M.CODEX_TIMEOUT_SECONDS = 120

-- True only when spawn_codex_sync returned a well-formed, successful result.
-- Mirrors the github-devloop guard: a transport/internal failure yields a
-- non-table or exit_code ~= 0.
function M.codex_succeeded(result)
  return type(result) == "table" and result.exit_code == 0
end

-- One-line, log-safe summary of a codex result for log.info. Never echoes
-- stdout/stderr payloads (which may be large); only the exit_code and the
-- engine-provided log_path are surfaced.
function M.format_result(result)
  if type(result) ~= "table" then
    return "codex returned no result table"
  end
  return string.format(
    "codex exit_code=%s log=%s",
    tostring(result.exit_code),
    tostring(result.log_path))
end

-- Payload raised on the hello_result queue. Carries only the exit_code and
-- log_path (safe identifiers), never the raw codex output.
function M.result_payload(result)
  local ok = M.codex_succeeded(result)
  return {
    message = M.MESSAGE,
    ok = ok,
    exit_code = (type(result) == "table" and result.exit_code) or -1,
    log_path = (type(result) == "table" and result.log_path) or "",
  }
end

return M
