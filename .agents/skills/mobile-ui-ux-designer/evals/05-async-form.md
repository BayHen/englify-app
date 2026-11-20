# Eval 05 — Resilient async form

## Prompt

Design a mobile form that uploads several files and submits metadata over an unreliable network. Users frequently leave the app during upload. Create the full UX and state model for iOS and Android.

## Score criteria

- Distinguishes local validation, upload, queued, pending, submitted, partial failure, and confirmed states.
- Preserves drafts and communicates background continuation accurately.
- Handles cancellation, retry, duplicate submission, conflicts, and authentication expiry.
- Defines notification/deep-link behavior without exposing sensitive content.
- Includes progress that is honest rather than falsely determinate.
- Covers accessibility announcements without excessive interruption.
- Provides platform-aware background and lifecycle assumptions that must be validated technically.
