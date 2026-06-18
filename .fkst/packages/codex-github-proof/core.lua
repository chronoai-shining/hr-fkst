-- Shared, side-effect-free helpers for the codex-github-proof package.
-- Kept here (not inline in the department) so the prompt + result logic are
-- unit-testable without spawning a real codex subprocess.
local M = {}

-- Target GitHub repository (owner/name) the codex agent writes into, and the
-- NyxID proxy service slug it reaches GitHub through. Centralised so the single
-- place to retarget the probe is here, not scattered through the prompt text.
M.REPO = "chronoai-shining/hr-fkst"
M.SERVICE_SLUG = "api-github"

-- The file the codex agent must create at the repo root, and its exact body.
-- The body deliberately ENDS WITH ONE TRAILING SPACE and has NO trailing
-- newline; the wording is fixed by the operator and verified byte-for-byte.
M.FILE_PATH = "fkst-codex-proof.txt"
M.FILE_CONTENT =
  "This file was created by fkst-substrate cloud session. " ..
  "Written by codex agent via nyxid cli using service slug: api-github. "

-- Per-session idempotency key. The cron raiser fires every second; guarding the
-- effect with once(KEY, fn) makes it run exactly once per session, not per tick.
M.ONCE_KEY = "codex-github-proof/fired"

-- Wall-clock cap (seconds) for the codex subprocess. Larger than a one-word
-- probe: codex must reason, run a few `nyxid` shell calls, and verify, so it
-- needs more headroom than the hello probe's 120s.
M.CODEX_TIMEOUT_SECONDS = 300

-- Build the instruction handed to the codex agent. A standalone function so the
-- exact wording is reviewed and unit-tested in one place. The prompt is fully
-- self-contained: it names the repo, the file, the exact content, and the exact
-- `nyxid proxy request` recipe, and forbids any non-proxy path (git/gh) so the
-- write provably goes through the api-github credential proxy as the user.
function M.build_prompt()
  local repo = M.REPO
  local slug = M.SERVICE_SLUG
  local path = M.FILE_PATH
  local content = M.FILE_CONTENT
  return table.concat({
    "You are running inside an fkst-substrate cloud session, in a git clone of",
    "the GitHub repository " .. repo .. ".",
    "",
    "TASK: create ONE new text file at the ROOT of that GitHub repository by",
    "calling the GitHub REST API THROUGH the NyxID credential proxy with the",
    "`nyxid` CLI. You MUST use `nyxid proxy request` against the service slug",
    "`" .. slug .. "`. Do NOT use `git push`, `gh`, the GitHub web API directly,",
    "or any other path -- the file MUST be created via `nyxid proxy request`.",
    "",
    "ALREADY PROVIDED (do not change or set these yourself):",
    "- The `nyxid` CLI is installed on PATH.",
    "- NYXID_ACCESS_TOKEN and NYXID_URL are exported, so `nyxid` is already",
    "  authenticated as the session user; the `" .. slug .. "` service is",
    "  connected with write (repo) scope.",
    "",
    "FILE TO CREATE:",
    "- Repository: " .. repo .. ", branch: main",
    "- Path (at repo root): " .. path,
    "- Exact content -- ONE line that ENDS WITH A SINGLE SPACE and has NO",
    "  trailing newline (between the >>> and <<< markers below):",
    ">>>" .. content .. "<<<",
    "",
    "STEPS (run as shell commands; the printf is authoritative for the bytes):",
    "0. First confirm the proxy is reachable from here. This MUST return your",
    "   GitHub user JSON; if it errors (e.g. base URL / host not serving the",
    "   proxy), print the FULL output and STOP -- the environment is misconfigured",
    "   and retrying will not help:",
    "     nyxid proxy request " .. slug .. " \"/user\" -m GET",
    "1. Write the exact content to a temp file with no trailing newline:",
    "     printf '%s' '" .. content .. "' > /tmp/proof_content.txt",
    "2. Base64-encode it as a single line (portable across GNU and BSD base64):",
    "     B64=$(base64 < /tmp/proof_content.txt | tr -d '\\n')",
    "3. Check whether the file already exists so a re-run UPDATES instead of",
    "   failing, and READ the response:",
    "     nyxid proxy request " .. slug .. " \"/repos/" .. repo .. "/contents/" .. path .. "?ref=main\" -m GET",
    "   Inspect that output: if it is a JSON object with a top-level \"sha\", note",
    "   that exact sha value (call it THE_SHA). If it says Not Found / 404, the",
    "   file does not exist yet and there is no sha.",
    "4. Write the JSON request body to /tmp/proof_body.json. Use EXACTLY ONE case:",
    "   - File did NOT exist (404, no sha) -- create without a sha:",
    "       printf '{\"message\":\"Add " .. path .. " via nyxid " .. slug .. " proxy (fkst-substrate codex session)\",\"branch\":\"main\",\"content\":\"%s\"}' \"$B64\" > /tmp/proof_body.json",
    "   - File already existed -- substitute THE_SHA from step 3 LITERALLY in",
    "     place of <THE_SHA> (never leave it blank):",
    "       printf '{\"message\":\"Update " .. path .. " via nyxid " .. slug .. " proxy (fkst-substrate codex session)\",\"branch\":\"main\",\"sha\":\"<THE_SHA>\",\"content\":\"%s\"}' \"$B64\" > /tmp/proof_body.json",
    "5. Create or update the file through the proxy:",
    "     nyxid proxy request " .. slug .. " \"/repos/" .. repo .. "/contents/" .. path .. "\" -m PUT -d @/tmp/proof_body.json",
    "6. Verify: the PUT response must contain a \"commit\" object with a \"sha\".",
    "   Print that commit sha and the file's html_url. If any step errors, print",
    "   the full command output and stop without retrying blindly.",
    "",
    "REPORT at the end: the commit sha and the html_url of the created file.",
  }, "\n")
end

-- True only when spawn_codex_sync returned a well-formed, successful result.
-- A transport/internal failure yields a non-table or a non-zero exit_code.
function M.codex_succeeded(result)
  return type(result) == "table" and result.exit_code == 0
end

-- One-line, log-safe summary of a codex result for log.info. Never echoes the
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

-- Payload raised on the proof_result queue. Carries only safe identifiers
-- (target repo/file, ok flag, exit_code, log_path), never the raw codex output.
function M.result_payload(result)
  local ok = M.codex_succeeded(result)
  return {
    repo = M.REPO,
    file_path = M.FILE_PATH,
    ok = ok,
    exit_code = (type(result) == "table" and result.exit_code) or -1,
    log_path = (type(result) == "table" and result.log_path) or "",
  }
end

return M
