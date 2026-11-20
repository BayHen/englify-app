# Mobile Interaction Patterns

Patterns are starting points, not substitutes for understanding the task. Use native components and current platform guidance where available.

## Navigation

### Top-level destinations

- Use a small set of stable peer destinations for persistent bottom navigation/tab presentation.
- Keep labels concise and specific.
- Preserve each destination's navigation state when users switch, unless product logic clearly requires reset.
- Do not use top-level navigation items as actions.
- Adapt presentation for larger windows rather than stretching the compact navigation unchanged.

### Hierarchical navigation

- Make the current location and parent relationship clear.
- Preserve expected system back behavior.
- Avoid deep chains created only to hide options.
- Return users to the prior scroll position and state when navigating back.

### Modal tasks

- Use modals for focused temporary work, not as the default navigation architecture.
- Make save, cancel, dismissal, and unsaved changes explicit.
- Avoid stacking multiple modals.
- Restore focus and context after dismissal.

## Onboarding

- Let users reach value as early as possible.
- Teach in context instead of front-loading every feature.
- Ask only for information required at the current stage.
- Delay account creation or permissions when the product can safely demonstrate value first.
- Show progress for genuinely multi-step setup.
- Allow exit and resume when setup is long.
- Do not use a carousel of generic feature claims as a substitute for onboarding.

## Authentication

- Support password managers, autofill, passkeys or platform-recommended methods where appropriate.
- Keep sign-in and sign-up routes distinguishable.
- Allow paste and one-time-code autofill.
- Explain account existence conflicts and recovery clearly.
- Avoid revealing sensitive account existence where security requires ambiguity.
- Preserve entered identifiers during recoverable errors.
- Provide accessible alternatives to biometrics and difficult cognitive tasks.

## Forms

- Use visible persistent labels.
- Choose the correct keyboard, content type, autofill hint, and input format.
- Group fields by user meaning, not database structure.
- Validate when the user can act on the feedback; avoid aggressive errors before interaction.
- Keep error text next to the field and summarize multiple errors when helpful.
- Do not enable submission that is guaranteed to fail; do not disable without explaining requirements.
- Preserve input and scroll/focus to the first actionable error.
- Break long forms at meaningful boundaries and show saved progress.

## Search and filtering

- Clarify whether search is local, remote, or scoped.
- Handle initial, typing, loading, results, no results, offline, and error states.
- Preserve the query and filters while moving between list and detail.
- Show active filters and provide a clear way to remove them.
- Use recent searches or suggestions only when useful and privacy-appropriate.
- Avoid submitting every keystroke to expensive or sensitive services without debounce and intent.

## Lists and detail

- Make row boundaries and tappable areas clear.
- Use a stable content hierarchy and consistent metadata placement.
- Separate row navigation from secondary actions semantically and visually.
- Preserve scroll position after detail navigation.
- For destructive row actions, provide a visible alternative to swipe and support undo when feasible.
- Use skeletons only when they approximate stable content; avoid misleading shapes and long fake loading.

## Creation and editing

- Distinguish create, edit, duplicate, draft, autosaved, and published states.
- Communicate whether changes save automatically or require explicit submission.
- Protect unsaved work during dismissal, interruption, or authentication expiry.
- Use previews when formatting or external visibility is consequential.
- Make ownership and audience clear before publishing or sending.

## Destructive and high-risk actions

- Name the object and consequence.
- Separate the action from common controls.
- Use confirmation only when risk warrants interruption.
- Require stronger confirmation for irreversible, broad, financial, security, or externally visible consequences.
- Prefer undo for common reversible deletion.
- Report partial failure accurately in batch operations.

## Permissions

- Ask at the moment a feature needs the capability.
- Explain the benefit and scope without coercion.
- Design denied, restricted, and limited-access states.
- Keep unrelated app functionality available when possible.
- Do not repeatedly prompt after denial; let user intent trigger the settings path.

## Notifications

- Ask for notification permission after demonstrating a relevant benefit.
- Provide granular in-app preferences.
- Deep-link to the relevant state, not a generic home screen.
- Avoid exposing sensitive content on lock screens by default when risk exists.
- Handle stale or already-resolved notifications gracefully.

## Loading and progress

- For near-immediate actions, use subtle local feedback.
- For uncertain waits, use an indeterminate indicator and meaningful status if available.
- For measurable work, show determinate progress only when the estimate is trustworthy.
- Prevent duplicate submission while preserving cancel or navigation when safe.
- Do not block the whole screen for a local update.
- Explain background continuation and completion notification.

## Empty states

Differentiate:

- first use;
- no user-created content;
- no search results;
- filters hiding results;
- no permission or unavailable capability;
- content not yet synced;
- loading failure.

Each state should explain the condition and provide the most relevant available action, without unnecessary illustration or marketing.

## Offline, timeout, and conflict

- Show cached content when safe and label staleness when it matters.
- Queue actions only when the app can reconcile them safely.
- Distinguish unsent, pending, failed, and confirmed states.
- Provide retry for transient failures and edit/cancel for invalid queued work.
- Resolve concurrent edits with transparent conflict handling; do not silently overwrite consequential changes.
- Keep drafts locally when privacy and product requirements allow.

## Gestures and direct manipulation

- Use gestures as accelerators, not hidden requirements.
- Provide visible controls or accessible actions for swipe, drag, reorder, zoom, and long press.
- Give continuous feedback during manipulation and a clear final state.
- Support cancel and undo.
- Respect platform gestures and safe edge regions.

## State matrix

For any substantial feature, document:

| Dimension | States to consider |
|---|---|
| Data | none, partial, complete, stale, conflicting |
| Network | online, slow, offline, timeout, server failure |
| Authorization | signed out, signed in, expired, insufficient permission |
| Permission | not requested, granted, limited, denied, restricted |
| Operation | idle, editing, validating, submitting, pending, success, failure |
| Accessibility | large text, screen reader, reduced motion, high contrast, non-touch input |
| Window | compact, medium, expanded, portrait, landscape, resized |

Only include states that are plausible, but never assume the happy path is the whole feature.
