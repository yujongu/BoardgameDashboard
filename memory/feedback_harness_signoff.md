---
name: Harness sign-off required before task completion
description: Before finishing any task, explicitly confirm ARCHITECT and TESTER roles have signed off per .harness/PROTOCOL.md
type: feedback
---

Before declaring any task done, explicitly confirm:
1. **ARCHITECT sign-off** — all checks in `.harness/ARCHITECT.md` cleared (no business logic in widgets, correct folder structure, `const` usage, no hardcoded strings, no cross-feature coupling)
2. **TESTER sign-off** — all checks in `.harness/TESTER.md` cleared (unit tests for providers, widget smoke/interaction tests, serialization tests if model changed, `flutter test` passes)

**Why:** User established a Harness Engineering environment on 2026-05-04 to enforce architectural and test quality gates on every task.

**How to apply:** At the end of every task response, include an explicit sign-off section stating whether ARCHITECT and TESTER have passed or flagging any outstanding issues. Also update `.harness/TASK_LOG.md` per the protocol.
