# Mobile Accessibility

Accessibility is a product-quality requirement, not a final compliance pass. Use native platform guidance together with WCAG 2.2 as a cross-platform baseline where applicable.

## Accessibility definition of done

A core task is not complete until a user can understand and finish it with:

- enlarged text and display settings;
- VoiceOver or TalkBack;
- touch without fine precision;
- an alternative to complex gestures and dragging;
- reduced motion;
- color-perception differences or high-contrast needs;
- keyboard, switch, or voice input where supported and relevant.

## Semantics

Every meaningful element needs the correct programmatic information:

- **name:** what the element is;
- **role/trait:** button, heading, checkbox, tab, image, adjustable control, and so on;
- **value:** current text, amount, progress, or selection;
- **state:** selected, expanded, disabled, checked, busy, invalid;
- **action:** what activation or custom action does;
- **grouping:** whether related visual fragments should be read as one item or separately;
- **order:** a logical traversal sequence that follows task and reading order.

Rules:

- Do not place the control type redundantly inside a label when the platform already announces the role.
- Icon-only actions require meaningful accessible names.
- Decorative images should be hidden from assistive technology.
- Status changes that occur away from focus need an appropriate accessible announcement without excessive interruption.
- Custom-drawn controls must expose the same semantics and actions as native equivalents.

## Text and reflow

- Use platform text styles and scalable units.
- Test the largest supported accessibility sizes, not only one moderate enlargement.
- Allow labels and buttons to wrap when meaning must be preserved.
- Avoid fixed-height containers around text.
- Keep content and controls available after reflow; do not hide actions at large text sizes.
- Maintain logical reading order when visual columns collapse.
- Do not encode essential text in images.

## Contrast and non-color cues

Use WCAG 2.2 AA as the minimum cross-platform reference where relevant:

- normal text generally needs at least 4.5:1 contrast;
- large text generally needs at least 3:1;
- meaningful non-text controls, focus indicators, and graphical objects generally need at least 3:1 against adjacent colors.

Also:

- test dynamic colors in light, dark, and high-contrast contexts;
- do not use color alone for success, warning, error, selection, or required fields;
- avoid placeholder text as the only label;
- preserve sufficient contrast in pressed, selected, disabled, and loading states.

## Touch targets and spacing

Use the stronger platform default for native apps:

- iOS: design around at least a 44 by 44 point hit region unless current Apple guidance changes;
- Android/Material: at least a 48 by 48 dp hit region;
- web or hybrid content: WCAG 2.2 AA Target Size (Minimum) provides a 24 by 24 CSS pixel minimum with defined exceptions, but platform-sized targets are usually a better mobile default.

The visible icon may be smaller than the hit region. Separate adjacent targets enough to reduce accidental activation. Make destructive targets especially distinct from common actions.

## Gestures, dragging, and motion

- Never make swipe, drag, long press, pinch, multi-finger input, or device motion the only way to complete a core action.
- Provide buttons, menus, steppers, reorder controls, or other alternatives.
- Expose custom accessibility actions for gesture-driven features.
- Respect reduced-motion settings and replace large movement with simpler transitions or crossfades where appropriate.
- Avoid flashing or rapidly repeating effects.
- Do not require users to act within a short time limit unless essential; provide extension or control when possible.

## Focus and navigation

- Focus should enter a screen at a predictable, useful location.
- Keep focus order aligned with reading and task sequence.
- Do not trap focus in a region unless it is a true modal, and provide a clear exit.
- Restore focus sensibly after dialogs, sheets, deletion, reordering, or navigation back.
- Ensure the focused item remains visible and is not covered by sticky headers, sheets, or keyboards.
- Provide visible focus for keyboard and non-touch users.
- Headings and landmarks should support efficient navigation on complex screens.

## Forms and authentication

- Keep visible labels associated with controls.
- State required fields in text or semantics, not only an asterisk or color.
- Describe errors specifically and associate them with the affected field.
- Do not erase valid input after an error.
- Use autofill, password managers, one-time-code APIs, and paste where safe.
- Avoid authentication that depends only on puzzles, memorization, transcription, or a specific biometric. Provide an accessible alternative.
- Show password requirements before submission and allow users to inspect the password when safe.

## Media, sound, and haptics

- Caption meaningful speech and audio.
- Provide transcripts or alternatives where appropriate.
- Do not rely on sound or haptics alone for status.
- Give users control over autoplaying media and avoid unexpected audio.
- Descriptive text or audio description may be needed when visual information is essential.

## Localization and cognition

- Use plain, concrete language and consistent terms.
- Break instructions into manageable steps.
- Avoid relying on spatial directions alone, such as "tap the green button on the right."
- Support locale-specific formats and right-to-left mirroring.
- Allow enough time to read and act.
- Keep help and recovery consistently available.
- Avoid unnecessary re-entry of information already supplied.

## Testing matrix

### iOS

- VoiceOver navigation and custom actions;
- Dynamic Type through the largest accessibility sizes;
- Bold Text, Increase Contrast, Differentiate Without Color, Reduce Transparency, Reduce Motion where relevant;
- Voice Control and Switch Control for core paths;
- landscape and keyboard when supported.

### Android

- TalkBack traversal, actions, and announcements;
- font size and display size at large settings;
- Accessibility Scanner;
- Switch Access and Voice Access for core paths;
- keyboard/D-pad focus on tablets, foldables, ChromeOS, or resizable windows where supported;
- predictive back with assistive technology active.

### General

- complete the primary task without seeing color;
- complete the primary task without gestures;
- complete the primary task after a validation error;
- complete the primary task after interruption or rotation/window resize;
- verify that loading and status updates are announced appropriately;
- verify focus after modal presentation and dismissal.

## Reporting

Accessibility reviews must identify:

- affected users and task;
- severity and reproducible condition;
- expected semantic or interaction behavior;
- platform-specific implementation guidance;
- whether the issue was verified manually, automatically, or inferred from code.

Do not claim WCAG or platform conformance based only on automated tests.
