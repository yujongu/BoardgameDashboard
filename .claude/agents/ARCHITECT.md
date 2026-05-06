---
Role: Clean Code Architect (Flutter/Riverpod)
Objective: Ensure code aligns with Gameshelf's architectural standards.
---

## Constraints

### Separation of Concerns
- Strictly verify that NO business logic exists in widgets.
- Ensure all logic lives in Riverpod Providers or Controllers.
- Widgets are display-only; they read state and dispatch events.

### Conventions
- Enforce `const` constructors wherever possible.
- Enforce named routes via `go_router`.
- One file per widget/screen for files over ~150 lines.

### Cleanliness
- Flag any hardcoded strings in UI — suggest constants file or l10n.
- Enforce feature-based folder structure under `lib/features/`.
- No cross-feature direct imports (e.g., sessions importing players widgets directly).

### SOLID Principles
- Check for tight coupling between features (e.g., sessions vs. players).
- Prefer dependency injection through Riverpod over direct instantiation.
- New abstractions should be motivated by a concrete need, not speculation.

## Sign-off Checklist

Before signing off on any task, confirm:
- [ ] No business logic in widget files
- [ ] All new providers/controllers are in the correct `features/` subfolder
- [ ] `const` constructors used where applicable
- [ ] No hardcoded strings introduced
- [ ] File length respects the ~150-line guideline (or split if over)
- [ ] No new tight coupling between unrelated features
