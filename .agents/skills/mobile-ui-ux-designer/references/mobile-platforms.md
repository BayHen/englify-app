# Mobile Platform Guidance

Use this reference whenever a feature targets iOS, Android, or a cross-platform stack.

## Shared product layer versus native behavior

Usually share:

- user goals and product terminology;
- information architecture at the conceptual level;
- domain rules and data model;
- core content hierarchy;
- brand voice and semantic brand tokens;
- analytics intent;
- accessibility outcomes.

Usually adapt:

- top-level navigation presentation;
- system back behavior and gestures;
- app bars, tab bars, navigation bars, rails, and drawers;
- modal sheets, dialogs, menus, pickers, switches, date/time controls, and selection patterns;
- permission education and system prompts;
- iconography and platform terminology;
- haptics, system materials, transitions, and system surfaces;
- safe areas, system bars, keyboard behavior, and window adaptation;
- accessibility APIs and testing tools.

Do not force pixel parity between platforms. Seek functional parity and equivalent clarity.

## iOS and iPadOS

### Experience principles

- Use familiar iOS navigation and controls unless the product has a strong, tested reason not to.
- Respect safe areas and system-owned gestures.
- Let content adapt to orientation, appearance, Dynamic Type, and device class.
- Prefer system components and SF Symbols when they meet the need; they inherit platform behavior and accessibility more reliably.
- Treat system materials and visual effects as functional layering tools. Verify current HIG and SDK behavior before adopting release-specific aesthetics.

### Navigation

- Use a navigation stack for hierarchical drill-down.
- Use a tab bar for a small set of persistent peer destinations, not for actions or temporary filters.
- Keep the current location and back destination understandable.
- Do not replace the standard back behavior with a custom close or home action unless the hierarchy genuinely changes.
- Use sheets for focused, temporary tasks. Make dismissal behavior and unsaved changes explicit.
- Avoid hidden edge gestures as the sole way to navigate or act.

### Layout and input

- Design around safe areas while allowing intentional edge-to-edge content where appropriate.
- Place frequent controls where they remain reachable without ignoring established placement conventions.
- Handle the keyboard without covering the focused field, validation message, or submission action.
- Use native text content types, keyboard types, autofill, password management, and input traits.
- Avoid fixed heights around text that can grow.

### Accessibility

- Support Dynamic Type, including accessibility categories.
- Use semantic accessibility labels, values, traits, actions, headings, and grouping.
- Keep custom controls behaviorally equivalent to native controls.
- Design touch targets at least around the current platform-recommended minimum; 44 by 44 points is the established iOS baseline unless current guidance specifies otherwise.
- Test VoiceOver order, rotor/headings where useful, reduce motion, differentiate without color, button shapes/increased contrast where relevant, and switch/voice control.

## Android

### Experience principles

- Use Material components and Android patterns as the default implementation vocabulary while expressing the product's brand through tokens.
- Draw edge-to-edge and deliberately handle status bars, navigation bars, cutouts, gesture insets, and keyboard insets.
- Treat adaptive design as a default. Android runs across phones, foldables, tablets, resizable windows, ChromeOS, and other form factors.
- Avoid portrait-only assumptions unless a task has an essential orientation requirement.

### Navigation

- Use navigation bars for a small set of primary peer destinations on compact widths; adapt to rails or other appropriate patterns at larger widths.
- Use drawers for broader or less-frequent destination sets when appropriate, not as a default for every app.
- Preserve Android's system back model. Back should move through the user's navigation history or dismiss the current transient layer as expected.
- Support predictive back and its system transitions through current AndroidX/platform APIs rather than intercepting back with obsolete patterns.
- Do not add an iOS-style back affordance that conflicts with Android system behavior.

### Layout and input

- Use window size classes or current adaptive layout APIs to drive pane count and navigation presentation.
- Reflow, reveal, or change component presentation instead of merely stretching phone layouts.
- Use maximum content widths and meaningful panes on large windows.
- Provide proper IME actions, autofill hints, input types, and keyboard avoidance.
- Test display size and font size changes independently.

### Accessibility

- Provide Compose semantics or View accessibility properties for names, roles, values, state, actions, and grouping.
- Use scalable text units and avoid containers that prevent text growth.
- Keep interactive target areas at least 48 by 48 dp as the Material/Android baseline, even when the visible icon is smaller.
- Do not use gestures as the only route to an action.
- Test TalkBack, Accessibility Scanner, Switch Access, Voice Access, large text/display settings, high-contrast modes where available, and keyboard/D-pad navigation on relevant devices.

## Cross-platform frameworks

A shared codebase does not require identical UI behavior.

### Architecture

- Separate semantic design tokens from platform-resolved tokens.
- Encapsulate platform differences in navigation, controls, permissions, haptics, system bars, text scaling, accessibility semantics, and dialogs/sheets.
- Prefer mature platform-adaptive components when they preserve expected behavior.
- Avoid scattered runtime platform checks inside every screen; centralize adaptation.
- Keep feature logic and content shared when practical.

### Framework notes

- **Flutter:** use `SafeArea` and current inset APIs deliberately; support text scaling; provide `Semantics`; choose Cupertino or Material behavior based on platform and product needs rather than mixing them casually.
- **React Native:** use accessible native primitives, `accessibilityRole`, labels, state, hints where useful, and platform modules for system behaviors. Validate that third-party components expose correct native semantics.
- **Kotlin Multiplatform:** share domain and presentation logic where useful, while allowing native SwiftUI and Compose surfaces to preserve platform conventions.
- **.NET MAUI and other wrappers:** inspect the native result. Abstraction does not guarantee correct focus, text scaling, system insets, or screen-reader output.

## Adaptive layout model

Define behavior for at least compact and expanded contexts; add intermediate behavior where the product benefits.

For each screen, specify:

- content maximum width;
- number and purpose of panes;
- navigation transformation;
- what reflows, reveals, collapses, or changes presentation;
- keyboard and input behavior;
- empty space strategy;
- fold/hinge avoidance;
- orientation support;
- restoration when the window changes size.

Do not simply scale every dimension upward. Large screens should improve context, comparison, navigation, or productivity.

## Platform review checklist

1. Does navigation behave as users of this platform expect?
2. Are system back, safe areas/insets, system bars, and keyboard handled correctly?
3. Are standard controls used where custom behavior adds no value?
4. Does text scale and reflow without fixed-height failures?
5. Are native accessibility semantics complete?
6. Does the app adapt beyond one portrait phone size?
7. Are permissions, haptics, sheets/dialogs, and system prompts platform-appropriate?
8. Has the result been inspected on both platforms rather than assumed from shared code?
