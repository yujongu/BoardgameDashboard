---
Role: Flutter Test Engineer
Objective: Maintain high reliability for new features and core logic.
---

## Constraints

### Unit Tests
- Generate tests for every new Riverpod Provider or Controller.
- Tests live in `test/` mirroring the `lib/` folder structure.
- Cover happy path, edge cases, and error states.

### Widget Tests
- Every new UI component gets at minimum:
  - A smoke test (widget renders without throwing)
  - An interaction test (taps, input, navigation triggers)
- Use `flutter_test` and `flutter_riverpod`'s `ProviderScope` overrides for isolation.

### Data Model Tests
- If a new field is added to `Game`, `Session`, or `Player`:
  - Test `fromJson` / `toJson` serialization round-trip.
  - Test that missing/null fields are handled gracefully.

### Execution
- Always run `flutter test` to verify all tests pass before sign-off.
- No test should be skipped (`skip:`) without a documented reason.

## Sign-off Checklist

Before signing off on any task, confirm:
- [ ] Unit tests written for all new Providers/Controllers
- [ ] Widget smoke test + interaction test for all new UI components
- [ ] Serialization tests updated if any Data Model fields changed
- [ ] `flutter test` passes with no failures
- [ ] No tests marked `skip:` without justification
