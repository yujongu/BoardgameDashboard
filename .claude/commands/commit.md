---
name: commit
description: Analyze staged/unstaged changes and create a git commit with a well-structured conventional commit message.
---

## Steps

### 1. Gather context

Run these in parallel:
- `git status` — see what files are staged, modified, or untracked
- `git diff --cached` — see exactly what is staged
- `git diff` — see unstaged changes (for awareness, not to commit blindly)
- `git log --oneline -10` — see recent commit style and conventions used in this repo

### 2. Decide what to stage

- Stage all changes including untracked files with `git add -A`.
- Never stage `.env`, credential files, or large binary files. If any are present, warn the user and exclude them.

### 3. Draft the commit message

Follow the **Conventional Commits** format used in this repo:

```
<type>(<optional scope>): <short imperative summary>

<optional body — explain the WHY, not the what>
```

**Type rules:**
- `feat` — new feature or capability
- `fix` — bug fix
- `refactor` — restructuring without behavior change
- `style` — formatting, lint fixes, no logic change
- `test` — adding or fixing tests
- `chore` — build system, deps, tooling, non-user-facing
- `docs` — documentation only

**Summary rules:**
- Imperative mood ("add", "fix", "remove" — not "added" or "fixes")
- Under 72 characters
- No trailing period
- Lowercase after the colon

**Body rules (include only if the WHY is non-obvious):**
- Blank line between summary and body
- Wrap at ~72 chars
- Explain motivation, constraints, or tradeoffs — not what the diff already shows

### 4. Confirm with the user

Show the user:
1. The list of files that will be committed
2. The proposed commit message

Ask: "Does this look right? Reply yes to commit, or tell me what to change."

### 5. Commit

Once confirmed:
```
git commit -m "$(cat <<'EOF'
<message here>
EOF
)"
```

Do not add any "Co-authored-by" or attribution lines to the commit message.

Do NOT push. Do NOT amend a previous commit unless the user explicitly asks.

### 6. Confirm success

Run `git log --oneline -3` and show the user the top entry so they can see the commit landed correctly.
