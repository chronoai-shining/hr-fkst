-- End-to-end department test: feed the department a cron event and assert it
-- exits cleanly and raises proof_result. The `codex` subprocess is mocked via
-- fkst.test.mock_command, so no real codex (and no live nyxid/api-github) is
-- touched -- this test exercises the department wiring, not the GitHub write.
local t = fkst.test

local CRON_EVENT = {
  queue = "proof_tick",
  payload = { raiser = "proof_tick" },
  ts = 1,
}

return {
  test_department_raises_result_on_codex_success = function()
    t.mock_command("codex", { stdout = "commit abc123", exit_code = 0 })

    local result = t.run_department(
      "departments/codex-github-proof/main.lua", CRON_EVENT)

    t.eq(result.exit_code, 0)
    t.eq(result.raises[1].queue, "proof_result")
    t.eq(result.raises[1].payload.repo, "chronoai-shining/hr-fkst")
    t.eq(result.raises[1].payload.file_path, "fkst-codex-proof.txt")
    t.is_true(result.raises[1].payload.ok)

    -- The department actually invoked the codex CLI exactly once.
    local calls = t.command_calls()
    t.eq(calls[1].program, "codex")
    t.is_nil(calls[2])
  end,

  test_department_marks_failure_when_codex_fails = function()
    t.mock_command("codex", { stderr = "boom", exit_code = 1 })

    local result = t.run_department(
      "departments/codex-github-proof/main.lua", CRON_EVENT)

    -- A codex failure does not crash the handler; it still exits 0 and raises a
    -- result with ok=false so the failure is observable downstream.
    t.eq(result.exit_code, 0)
    t.eq(result.raises[1].queue, "proof_result")
    t.eq(result.raises[1].payload.ok, false)
    t.eq(result.raises[1].payload.exit_code, 1)
  end,
}
