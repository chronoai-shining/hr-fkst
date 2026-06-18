# AGENTS.md — per-repo fkst base instructions

This file is the **base instruction set prepended to every fkst session spawned
from this repository**. It is read by the coding agent (codex) — hence the
uppercase `AGENTS.md` name — and `fkst-hosted` injects its contents ahead of the
goal-specific prompt at session start.

Edit this file to give every session in this repo shared context: coding
conventions, architectural constraints, the layout of the codebase, what to
avoid, and any house rules. Keep it concise and durable — it applies to *all*
sessions, so put goal-specific detail in the goal itself, not here.

> Note: the session-time injection of this file is handled by fkst-hosted; this
> file only needs to contain the instructions you want every session to see.
