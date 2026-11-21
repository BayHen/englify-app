# Eval 02 — Navigation audit

## Prompt

Review a cross-platform app that uses a hamburger drawer with twelve destinations on both iOS and Android. It also overrides the Android back button to always return to Home. Provide prioritized findings and a migration recommendation.

## Score criteria

- Identifies the broken Android system-back model as a high-priority issue.
- Does not blindly prescribe identical navigation on both platforms.
- Groups destinations by user task and considers top-level versus secondary navigation.
- Addresses state preservation and deep links.
- Covers predictive back and modal dismissal.
- Considers expanded/tablet navigation presentation.
- Gives a staged migration and verification plan.
