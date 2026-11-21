# Mobile Design Systems

A design system is a maintained product infrastructure, not merely a component gallery.

## Start from repeated product needs

Do not build a large abstract system before the product reveals useful patterns.

- Inventory existing screens, components, and visual decisions.
- Identify repeated high-value patterns and the inconsistencies causing user or engineering cost.
- Pilot the system on a representative product area.
- Measure adoption and task outcomes, not only the number of documented components.
- Keep an escape hatch for legitimate product needs, with a contribution path back into the system.

## Token model

Use semantic layers:

1. **Primitive tokens:** raw palette values, type sizes, spacing values, radii, durations.
2. **Semantic tokens:** surface, text-primary, action-primary, status-error, focus-ring.
3. **Component tokens:** button-primary-background, field-error-border, navigation-selected-label.
4. **Platform resolution:** iOS and Android values or APIs that satisfy the same semantic role.

Rules:

- Screens consume semantic or component tokens, not raw values.
- Support light, dark, high-contrast, and platform appearance changes.
- Version token changes and describe migration impact.
- Do not force identical dimensions across platforms when native components differ.

## Component specification

Every reusable component should document:

- purpose and when not to use it;
- anatomy and content slots;
- variants and sizes;
- default, pressed, focused, hovered where relevant, selected, disabled, busy, error, and success states;
- interaction and keyboard/back behavior;
- accessibility role, name, value, state, target area, focus order, and announcements;
- text scaling and localization behavior;
- responsive/adaptive behavior;
- platform differences;
- content guidance;
- examples and anti-examples;
- implementation API and test coverage.

Use [../assets/component-spec-template.md](../assets/component-spec-template.md).

## Component boundaries

Create a reusable component when:

- the same user problem repeats;
- behavior and semantics are stable;
- centralizing it reduces inconsistency or accessibility risk;
- variants can be expressed without a large matrix of boolean flags.

Do not create a component only because two screens look similar. Do not create a universal component whose API hides multiple unrelated patterns.

Prefer composition over adding many conditional props. Separate components when purpose, semantics, or behavior differ substantially.

## Platform strategy

A cross-platform design system should provide:

- shared semantic tokens and product vocabulary;
- equivalent component intent;
- platform-specific implementations where navigation, controls, system surfaces, haptics, focus, or semantics differ;
- explicit documentation of shared versus adapted behavior;
- parity tests based on user outcomes, not pixel identity.

## Governance

Define:

- owner or steward;
- contribution and review process;
- accessibility review requirements;
- release/versioning model;
- deprecation and migration policy;
- documentation ownership;
- adoption support and feedback channels.

A contribution should include the user need, evidence of reuse, platform behavior, states, accessibility, code, documentation, and migration implications.

## Adoption

- Integrate components into the actual development workflow and starter templates.
- Make the correct path easier than local reinvention.
- Provide examples from real product use.
- Track usage, overrides, defects, accessibility issues, and delivery time.
- Remove or merge components that create confusion.
- Treat support and education as part of the system.

## Review checklist

1. Does the system solve repeated user and delivery problems?
2. Are semantic tokens separated from raw values?
3. Are all interaction and accessibility states specified?
4. Are iOS and Android differences explicit?
5. Can components handle text growth, localization, and adaptive layouts?
6. Is the API composable rather than dominated by flags?
7. Is ownership and migration clear?
8. Is adoption measured through real product usage and quality?
