# Mobile UI/UX Designer Skill

A cross-compatible Agent Skill for designing, reviewing, specifying, and implementing general mobile app interfaces for iOS and Android.

The package is intentionally framework-neutral. It works with native SwiftUI/UIKit, Jetpack Compose/Views, Flutter, React Native, Kotlin Multiplatform, .NET MAUI, and other mobile stacks, while requiring platform-specific behavior where iOS and Android conventions differ.

## What it contains

- `SKILL.md` — the compact operating workflow loaded by Codex or Claude Code.
- `references/` — detailed, original synthesis of platform guidance and acclaimed UX literature.
- `assets/` — reusable briefs, flow, screen, component, and review templates.
- `scripts/audit_ui.py` — a dependency-free heuristic static audit that identifies files worth manual review.
- `evals/` — test prompts and scoring criteria for evaluating the skill.
- `install.ps1` and `install.sh` — project- or user-level installation for Codex, Claude Code, or both.

## Install on Windows PowerShell

From the extracted folder:

```powershell
# Install for the current repository in both Codex and Claude Code
.\install.ps1 -Scope Project -Target Both -ProjectPath "C:\path\to\your\repo"

# Install globally for your user account
.\install.ps1 -Scope User -Target Both
```

## Install on macOS or Linux

```bash
# Current repository, both tools
./install.sh --scope project --target both --project /path/to/repo

# User-level, both tools
./install.sh --scope user --target both
```

## Manual installation

Copy the entire `mobile-ui-ux-designer-skill` directory, retaining its contents, to one or both locations:

```text
# Codex repository skill
<repo>/.agents/skills/mobile-ui-ux-designer/

# Codex personal skill
~/.agents/skills/mobile-ui-ux-designer/

# Claude Code repository skill
<repo>/.claude/skills/mobile-ui-ux-designer/

# Claude Code personal skill
~/.claude/skills/mobile-ui-ux-designer/
```

Codex can invoke the skill explicitly from the skill picker or by mentioning `$mobile-ui-ux-designer`. Claude Code can invoke it with `/mobile-ui-ux-designer`. Both may load it automatically when a request matches the description.

## Example requests

```text
Use the mobile UI/UX designer skill to redesign this onboarding flow for iOS and Android, then implement it.
```

```text
Audit the profile-editing flow for usability, Dynamic Type, TalkBack/VoiceOver, error recovery, and platform consistency. Do not change code.
```

```text
Create a component and state specification for this mobile checkout screen, including loading, offline, validation, success, and failure states.
```

```text
Review this Flutter app and identify where shared UI should remain common and where behavior should adapt by platform.
```

## Run the heuristic audit

```bash
python scripts/audit_ui.py /path/to/mobile/project
python scripts/audit_ui.py /path/to/mobile/project --format json --output ui-audit.json
```

The script finds review candidates; it cannot determine whether the final experience is usable or accessible. Verify on devices with assistive technologies.

## Updating platform guidance

Apple, Android, Material, and accessibility guidance evolve. The skill instructs agents with web access to verify release-sensitive behavior against current official documentation. Review `references/source-notes.md` periodically and update any platform-specific rules that have changed.

## Copyright and synthesis

This package does not contain copied book chapters. Its guidance is an original synthesis and paraphrase of the sources listed in `references/source-notes.md`. The source books remain copyrighted by their respective authors and publishers and are not redistributed here.
