# Mobile Screen Specification

## Identity

- Screen name:
- User goal:
- Entry points:
- Exit points:
- Platforms:

## Hierarchy

1. Primary information:
2. Primary action:
3. Secondary information/actions:
4. Supporting or optional content:

## Layout

- Compact layout:
- Medium/expanded layout:
- Safe area/system bar behavior:
- Keyboard behavior:
- Orientation/resizing behavior:
- Maximum content width/panes:

## Components

| Component | Purpose | Content | Interaction | Reused/new |
|---|---|---|---|---|
| | | | | |

## States

| State | Trigger | Visible UI | Available actions | Accessible announcement/focus |
|---|---|---|---|---|
| Initial loading | | | | |
| Content | | | | |
| Empty | | | | |
| Offline | | | | |
| Error | | | | |
| Submitting/busy | | | | |
| Success | | | | |
| Disabled/restricted | | | | |

## Validation and recovery

- Validation timing:
- Field errors:
- Screen-level errors:
- Preserved data:
- Retry/undo/cancel:

## Accessibility

- Screen title/heading:
- Focus entry:
- Reading order:
- Control names, roles, values, states:
- Custom actions:
- Dynamic Type/font scaling:
- Target sizing:
- Color-independent cues:
- Reduced motion:
- Keyboard/switch/voice behavior:

## Platform adaptations

### iOS

- Navigation:
- Components:
- Gestures/haptics:
- VoiceOver/Dynamic Type:

### Android

- Navigation/predictive back:
- Components:
- Edge-to-edge/adaptive layout:
- TalkBack/font and display scaling:

## Analytics and privacy

- Events needed:
- Sensitive data excluded:
- Consent/visibility concerns:

## Acceptance criteria

- [ ] Happy path works.
- [ ] Recovery path works without losing valid input.
- [ ] Loading, empty, offline, error, and success states are implemented where applicable.
- [ ] Screen works at largest supported text sizes.
- [ ] Screen-reader order and labels are verified.
- [ ] Platform back, system UI, keyboard, and insets behave correctly.
- [ ] Compact and expanded layouts are inspected.
