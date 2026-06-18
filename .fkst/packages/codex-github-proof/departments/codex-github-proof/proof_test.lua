-- Unit tests for the pure helpers in core.lua. These cover the prompt
-- invariants and the result helpers without spawning codex; the end-to-end
-- department behaviour (print + spawn_codex_sync + raise) is exercised in
-- tests/run_department_test.lua.
local core = require("core")
local t = fkst.test

return {
  test_target_constants = function()
    t.eq(core.REPO, "chronoai-shining/hr-fkst")
    t.eq(core.SERVICE_SLUG, "api-github")
    t.eq(core.FILE_PATH, "fkst-codex-proof.txt")
  end,

  test_content_ends_with_single_space_and_no_newline = function()
    -- The trailing space is part of the required bytes; a stray newline would
    -- change the artifact, so guard both invariants.
    t.eq(core.FILE_CONTENT:sub(-1), " ")
    t.is_nil(core.FILE_CONTENT:find("\n"))
  end,

  test_content_is_the_exact_message = function()
    t.eq(
      core.FILE_CONTENT,
      "This file was created by fkst-substrate cloud session. " ..
        "Written by codex agent via nyxid cli using service slug: api-github. ")
  end,

  test_prompt_is_self_contained = function()
    local p = core.build_prompt()
    -- The agent must be told the repo, the proxy mechanism, the slug, the file,
    -- the HTTP verb, and the forbidden alternatives.
    t.is_true(p:find("chronoai%-shining/hr%-fkst", 1, false) ~= nil)
    t.is_true(p:find("nyxid proxy request", 1, true) ~= nil)
    t.is_true(p:find("api%-github", 1, false) ~= nil)
    t.is_true(p:find("fkst%-codex%-proof%.txt", 1, false) ~= nil)
    t.is_true(p:find("-m PUT", 1, true) ~= nil)
    t.is_true(p:find("git push", 1, true) ~= nil)
    -- The exact content must appear verbatim inside the instruction.
    t.is_true(p:find(core.FILE_CONTENT, 1, true) ~= nil)
  end,

  test_codex_succeeded_true_on_exit_zero = function()
    t.is_true(core.codex_succeeded({ exit_code = 0, log_path = "/x" }))
  end,

  test_codex_succeeded_false_on_nonzero = function()
    t.eq(core.codex_succeeded({ exit_code = 1 }), false)
  end,

  test_codex_succeeded_false_on_non_table = function()
    t.eq(core.codex_succeeded(nil), false)
  end,

  test_format_result_is_log_safe = function()
    -- Only exit_code + log_path are surfaced; stdout/stderr never appear.
    t.eq(
      core.format_result({ exit_code = 0, log_path = "/runs/1.log", stdout = "SECRET" }),
      "codex exit_code=0 log=/runs/1.log")
  end,

  test_format_result_handles_missing_table = function()
    t.eq(core.format_result(nil), "codex returned no result table")
  end,

  test_result_payload_on_success = function()
    local p = core.result_payload({ exit_code = 0, log_path = "/runs/1.log" })
    t.eq(p.repo, "chronoai-shining/hr-fkst")
    t.eq(p.file_path, "fkst-codex-proof.txt")
    t.is_true(p.ok)
    t.eq(p.exit_code, 0)
    t.eq(p.log_path, "/runs/1.log")
  end,

  test_result_payload_on_failure = function()
    local p = core.result_payload({ exit_code = 7 })
    t.eq(p.ok, false)
    t.eq(p.exit_code, 7)
    t.eq(p.log_path, "")
  end,
}
