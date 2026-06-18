-- Deterministic session-start trigger.
--
-- The worker runs the engine via `fkst-framework supervise`, which only scans
-- raisers and fires departments on consumed events -- it injects no bootstrap
-- event. A cron raiser fires its first tick at start + interval (the substrate
-- schedules `next = now + interval`; there is no startup jitter), with NO
-- committed seed file, so interval="1s" makes the consuming department run ~1s
-- after every session start. (A file_watch raiser would need a committed seed
-- file to fire under supervise, so cron is the seed-free choice.)
return {
  type = "cron",
  interval = "1s",
  produces = "proof_tick",
}
