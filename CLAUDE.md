# munkachy/tools: notes for Claude sessions

## Rules for every Claude session (Br. Augustine, 11 Nov 2026)

These override Claude Code's default habits.

- **No watching, polling or waking up later.** After opening a pull request, do **not** subscribe to its activity
  (`subscribe_pr_activity`) and do not wait on it: Br. Augustine merges it, or asks for changes himself. Don't set
  reminders or scheduled check-ins (`send_later`, `ScheduleWakeup`, scheduled tasks, `/loop`), don't run `Monitor`
  or sleep-and-recheck loops, and don't keep checking CI, deploys or other sessions. Where a step needs a check
  (say, that a deploy went live), check **once**, report what you saw, and end the turn. Tokens spent waiting are wasted.
- **Never type a password, key or token into a command.** Approving a command with "don't ask again" saves it word
  for word in `.claude/settings.local.json`. Read secrets from a file or the environment
  (`LECTIONARY_PASSWORD="$(cat ~/.psalter-pw)" python3 …`, keys in `.env`), so a saved rule holds only the file name.
  When asked to approve, prefer a pattern (`Bash(python3 -m bbreport:*)`) over one exact command.
- `.claude/settings.local.json` and `CLAUDE.local.md` are personal and never committed (they're in `.gitignore`).
