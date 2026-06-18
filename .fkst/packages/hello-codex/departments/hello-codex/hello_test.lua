-- Unit tests for the pure helpers in core.lua. These cover the success and
-- failure branches without spawning codex; the end-to-end department behaviour
-- (print + spawn_codex_sync + raise) is exercised in tests/run_department_test.lua.
local core = require("core")
local t = fkst.test

return {
  test_message_is_hello = function()
    t.eq(core.MESSAGE, "hello")
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
    t.eq(p.message, "hello")
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
