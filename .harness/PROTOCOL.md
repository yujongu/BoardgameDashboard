---
Protocol: The Gameshelf Loop
---

## Steps

### 1. SYNC
- Read `.harness/TASK_LOG.md`.
- Review the current task's status and any open blockers from the previous cycle.

### 2. ARCHITECT
- Run a check on staged/changed code against `.harness/ARCHITECT.md`.
- Confirm: no business logic in widgets, correct folder structure, `const` usage, no hardcoded strings, no cross-feature coupling.
- Record any violations found.

### 3. TEST
- Draft new tests per `.harness/TESTER.md` requirements.
- Cover all new Providers, Controllers, and UI components.
- Update serialization tests if any Data Model fields changed.

### 4. VERIFY
- Run `flutter analyze` — resolve all errors and warnings.
- Run `flutter test` — all tests must pass.
- Do not proceed to step 5 if either command reports failures.

### 5. VISUAL
- Explicitly remind the user:
  > **Visual verification required.** Please run `flutter run` on a simulator or device to confirm layout, colors, and interactions look correct. Static analysis cannot catch visual regressions.

### 6. LOG
- Update `.harness/TASK_LOG.md`:
  - Mark task status (Complete / Blocked / In Progress).
  - Note ARCHITECT sign-off result.
  - Note TESTER sign-off result.
  - Record any outstanding issues or follow-up tasks.

## GIT & COMMIT POLICY

- **Allowed**: `git add`, `git commit -m "..."`.
- **Forbidden**: `git push`, `git remote`, `git reset --hard` (on tracked files), or any `rm` command on project assets.
- **Commit Pattern**: Always use conventional commits (e.g., `feat:`, `fix:`, `refactor:`).
- **Review**: Before committing, the Architect must verify the staged changes.

## Sign-off Gate

A task is **not complete** until:
- ARCHITECT has signed off (all checklist items in `ARCHITECT.md` cleared)
- TESTER has signed off (all checklist items in `TESTER.md` cleared)
- `flutter analyze` and `flutter test` both pass
- User has been prompted for visual verification
