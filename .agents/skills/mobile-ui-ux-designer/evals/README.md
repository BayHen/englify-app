# Skill Evaluation Set

Use these scenarios to test whether the skill changes agent behavior in useful ways.

## Method

Run each prompt twice against the same representative repository or supplied mock context:

1. without explicitly invoking the skill;
2. with the skill installed and explicitly invoked.

Score each response from 0 to 2 on every criterion:

- **0:** absent, incorrect, or harmful;
- **1:** partially addressed or generic;
- **2:** specific, correct, actionable, and verified where possible.

A strong skill-assisted result should:

- identify the user goal before styling;
- distinguish iOS and Android behavior;
- include non-happy-path states;
- include accessibility semantics and testing;
- reuse the design system/codebase;
- avoid arbitrary visual trends;
- report verification honestly.

The evaluation prompts are intentionally framework-diverse and not tied to any particular product domain.
